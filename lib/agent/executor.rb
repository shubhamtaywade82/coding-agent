# frozen_string_literal: true

require_relative "../tools/index"

module Agent
  # Executor wrapper that uses AgentRuntime::Executor
  # Executes tool calls via ToolRegistry
  class Executor
    def initialize(tool_registry:)
      @executor = AgentRuntime::Executor.new(tool_registry: tool_registry)
    end

    # Delegate to AgentRuntime::Executor
    def execute(decision, state: nil)
      # Log each step/decision
      if decision.respond_to?(:action) && decision.respond_to?(:params)
        action = decision.action
        params = decision.params
        confidence = decision.respond_to?(:confidence) ? decision.confidence : "N/A"

        # Format params for logging (truncate long content)
        params_str = if params.is_a?(Hash)
                        formatted = params.dup
                        if formatted["content"] && formatted["content"].length > 100
                          formatted["content"] = "#{formatted["content"][0..100]}... (#{formatted["content"].length} chars)"
                        end
                        formatted.inspect
                      else
                        params.inspect
                      end

        $stdout.puts "\n[STEP] Action: #{action}"
        $stdout.puts "       Params: #{params_str}"
        $stdout.puts "       Confidence: #{confidence}"

        # Warn if required params are missing
        tools_requiring_params = %w[create_file read_file apply_patch ruby_syntax_check rubocop_check]
        if tools_requiring_params.include?(action) && (params.nil? || (params.is_a?(Hash) && params.empty?))
          $stderr.puts "⚠️  WARNING: #{action} requires parameters but received empty params"
        end
      end

      result = @executor.execute(decision, state: state)

      # Log result summary
      if result.is_a?(Hash)
        status = result["status"] || result[:status] || "completed"
        $stdout.puts "       Result: #{status}"
      end

      result
    end

    # Build tool registry from Tools::ALL
    def self.build_tool_registry
      tools_hash = {}
      Tools::ALL.each do |tool_class|
        tool_name = tool_class.name
        tools_hash[tool_name] = lambda do |*args, **kwargs|
          # Tool registry may call with:
          # 1. call(params_hash) - params as single hash
          # 2. call(tool_name, params_hash) - tool name + params
          # 3. call(**params) - params as keyword args
          # 4. call() - no args (agent_runtime bug)

          # Skip first arg if it's the tool name (string matching our tool_name)
          actual_args = if !args.empty? && args.first == tool_name
                          args[1..]
                        else
                          args
                        end

          # Extract arguments
          raw_args = if !kwargs.empty?
                       kwargs
                     elsif !actual_args.empty? && actual_args.first.is_a?(Hash)
                       actual_args.first
                     else
                       {}
                     end

          # Normalize keys to strings
          raw_args = raw_args.transform_keys(&:to_s) if raw_args.is_a?(Hash)

          # Extract params - handle nested structure
          args_hash = if raw_args.is_a?(Hash) && raw_args.key?("params")
                        params_value = raw_args["params"]
                        params_value.is_a?(Hash) ? params_value : {}
                      else
                        raw_args
                      end

          # Ensure hash type
          args_hash = {} unless args_hash.is_a?(Hash)

          # Handle parameter name mismatches (LLM sometimes uses wrong names)
          # Map common variations to "path" for tools that expect single path
          if args_hash.is_a?(Hash) && !args_hash.key?("path")
            # Try "file_path" -> "path"
            if args_hash.key?("file_path")
              args_hash["path"] = args_hash["file_path"]
            # Try "files" array -> "path" (use first file)
            elsif args_hash.key?("files")
              files_value = args_hash["files"]
              if files_value.is_a?(Array) && !files_value.empty?
                args_hash["path"] = files_value.first
              elsif files_value.is_a?(String)
                args_hash["path"] = files_value
              end
            # Try "file" -> "path"
            elsif args_hash.key?("file")
              args_hash["path"] = args_hash["file"]
            end
          end

          # Log when params are missing
          tools_requiring_path = %w[create_file read_file apply_patch ruby_syntax_check rubocop_check]
          if tools_requiring_path.include?(tool_name) && !args_hash.key?("path")
            $stderr.puts "WARNING [#{tool_name}]: Missing 'path'. Args: #{args.inspect}, Actual_args: #{actual_args.inspect}, Kwargs: #{kwargs.inspect}, Raw_args: #{raw_args.inspect}"
          end

          # Execute tool and log result
          begin
            result = tool_class.call(args_hash, _state: nil)

          # Log tool execution result (summary only)
          if result.is_a?(Hash)
            if result.key?("status")
              $stdout.puts "       ✓ Status: #{result['status']}"
            elsif result.key?("ok")
              if tool_name == "ruby_syntax_check"
                if result["ok"]
                  $stdout.puts "       ✓ Syntax: OK"
                else
                  error_msg = result["error"] || "Unknown error"
                  # Truncate long error messages
                  error_display = error_msg.length > 200 ? "#{error_msg[0..200]}..." : error_msg
                  $stdout.puts "       ✗ Syntax: FAILED"
                  $stdout.puts "       Error: #{error_display}"
                end
              else
                $stdout.puts "       ✓ Result: #{result['ok'] ? 'OK' : 'Failed'}"
              end
            elsif result.key?("files")
              $stdout.puts "       ✓ Found #{result['files'].is_a?(Array) ? result['files'].count : 0} files"
            elsif result.key?("results")
              $stdout.puts "       ✓ Found #{result['results'].is_a?(Array) ? result['results'].count : 0} results"
            end
          end

            result
          rescue ArgumentError => e
            # Handle "File already exists" error by reading the file and suggesting apply_patch
            if tool_name == "create_file" && e.message.include?("File already exists")
              file_path = args_hash["path"]
              if file_path
                begin
                  # Try to read the existing file
                  read_result = Tools::Repo::ReadFile.call({ "path" => file_path }, _state: nil)
                  $stdout.puts "       ⚠️  File already exists. Read existing content (#{read_result['lines']} lines)."
                  $stdout.puts "       💡 Use apply_patch to modify the file instead of create_file."

                  # Return a structured response that includes the file content
                  # This allows the agent to use apply_patch with the sha256
                  {
                    status: "file_exists",
                    message: "File already exists. Use apply_patch to modify it.",
                    file: {
                      path: read_result["path"],
                      content: read_result["content"],
                      sha256: read_result["sha256"],
                      lines: read_result["lines"]
                    }
                  }
                rescue StandardError => read_error
                  # If we can't read it, just return the original error
                  raise e
                end
              else
                raise e
              end
            else
              raise e
            end
          end
        end
      end
      AgentRuntime::ToolRegistry.new(tools_hash)
    end
  end
end
