# frozen_string_literal: true

require_relative "../tools/index"

module Agent
  # Planner wrapper that uses AgentRuntime::Planner
  # Uses ollama-client /generate endpoint for planning
  class Planner
    def initialize(client:, model: "qwen2.5-coder")
      @client = client
      @model = model

      # Define schema for planning decisions
      @schema = {
        type: "object",
        required: ["action"],
        properties: {
          action: { type: "string" },
          params: { type: "object" },
          confidence: { type: "number", minimum: 0, maximum: 1 }
        }
      }

      # Build tool descriptions with required parameters
      tool_descriptions = Tools::ALL.map do |tool_class|
        tool_name = tool_class.name
        case tool_name
        when "list_files"
          "#{tool_name}(path: optional, glob: optional) - List files in directory"
        when "read_file"
          "#{tool_name}(path: required) - Read file content"
        when "search"
          "#{tool_name}(query: required, path: optional) - Search for text in files"
        when "create_file"
          "#{tool_name}(path: required, content: required) - Create new file"
        when "apply_patch"
          "#{tool_name}(path: required, edits: required array of objects, sha256: optional) - Apply patch edits. Each edit must be: {start_line: integer, end_line: integer, replacement: string}. Example: [{start_line: 1, end_line: 5, replacement: 'new code\\n'}]"
        when "diff_preview"
          "#{tool_name}(path: optional) - Show git diff"
        when "revert_last_change"
          "#{tool_name}() - Revert last change"
        when "ruby_syntax_check"
          "#{tool_name}(path: required) - Validate Ruby syntax"
        when "rubocop_check"
          "#{tool_name}(path: required) - Check Ruby code style"
        when "collect_errors"
          "#{tool_name}() - Collect validation errors"
        else
          tool_name
        end
      end.join("\n")

      # Create prompt builder
      @prompt_builder = lambda do |input:, state: nil| # rubocop:disable Lint/UnusedBlockArgument
        <<~PROMPT
          You are a coding task planner.

          Rules:
          - Do NOT write code directly
          - CRITICAL: If task mentions "Calculator" or "calculator.rb", IMMEDIATELY call read_file with path "calculator.rb" - do NOT call list_files first
          - For tasks involving specific files (like "Calculator class"), go DIRECTLY to that file using read_file
          - If the task mentions a specific file name (e.g., "calculator.rb"), use read_file with that path immediately - skip list_files entirely
          - NEVER call list_files more than 2 times - if you don't find the file after 2 attempts, try read_file directly
          - If list_files shows a file exists, IMMEDIATELY call read_file on that file - do NOT call list_files again
          - To check if a file exists: call read_file - if it succeeds, file exists; if it fails, file doesn't exist
          - If read_file succeeds (file exists): use apply_patch to modify it - NEVER use create_file for existing files
          - If read_file fails (file doesn't exist): use create_file with BOTH path AND content parameters
          - create_file REQUIRES both "path" and "content" parameters - never call it without content
          - Use apply_patch for all file edits (never use create_file for existing files)
          - Do NOT call read_file multiple times on the same file - read it once, then use apply_patch
          - After creating or editing a file, validate syntax ONCE
          - If syntax check passes, the task is complete - STOP and do not repeat validation
          - If syntax check fails, read the error message, fix the issue using apply_patch, then validate again
          - Do NOT repeatedly validate the same file without making changes
          - Do NOT call the same tool with the same parameters more than once - if you already called list_files with "playground/", do NOT call it again
          - ALWAYS include required parameters in params
          - All file operations are restricted to the "playground/" directory
          - Paths are automatically scoped to playground/ (e.g., "calculator.rb" becomes "playground/calculator.rb")
          - When the task is complete (file created/edited and syntax valid), STOP - do not continue looping

          Available tools and their parameters:
          #{tool_descriptions}

          Important:
          - Use "path" (not "file_path" or "files") for file path parameters
          - Paths are relative to playground/ directory (e.g., use "calculator.rb" not "playground/calculator.rb")
          - For apply_patch, edits MUST be an array of objects, each with:
            * start_line: integer (line number where edit starts, 1-indexed)
            * end_line: integer (line number where edit ends, inclusive)
            * replacement: string (the new code to replace lines start_line through end_line)
          - Example apply_patch params: {"path": "file.rb", "edits": [{"start_line": 1, "end_line": 3, "replacement": "class NewClass\\n  def method\\n  end\\nend\\n"}]}

          Completion Criteria:
          - Task is complete when: file is created/edited AND syntax check passes (ok: true)
          - CRITICAL: If ruby_syntax_check returns {ok: true}, the task is COMPLETE - IMMEDIATELY STOP
          - Do NOT call any more tools after syntax check passes
          - Do NOT read the file again after syntax check passes
          - Do NOT list files after syntax check passes
          - If syntax check fails (ok: false), read the error, fix it with apply_patch, then validate again
          - Do NOT repeatedly call the same tool with the same parameters without making changes
          - Maximum 3 syntax checks per file - if still failing after 3 attempts, stop and report

          CRITICAL: When using apply_patch:
          - You MUST provide actual code in the replacement field
          - If the file is empty, corrupted, or has syntax errors, REPLACE THE ENTIRE FILE by using start_line=1 and end_line=(last line number)
          - To replace entire file: read_file first to get line count, then use {"start_line": 1, "end_line": <total_lines>, "replacement": "complete new file content\\n"}
          - If file has duplicate code or malformed structure, replace the ENTIRE file content, not just parts
          - Example: If file has 24 lines and is corrupted, use: {"start_line": 1, "end_line": 24, "replacement": "class Calculator\\n  def initialize\\n    @result = 0\\n  end\\n\\n  def add(num)\\n    @result += num\\n  end\\n\\n  def subtract(num)\\n    @result -= num\\n  end\\nend\\n"}
          - NEVER call apply_patch with an empty edits array
          - The replacement must contain actual Ruby code, not empty strings
          - After applying a patch, ALWAYS call ruby_syntax_check to validate

          Task:
          #{input}

          Output a JSON decision with:
          - action: The tool to use (must be one of the available tools listed above)
          - params: Parameters for the tool (MUST include all required parameters)
          - confidence: Your confidence (0.0 to 1.0)
        PROMPT
      end

      # Create AgentRuntime::Planner
      @planner = AgentRuntime::Planner.new(
        client: @client,
        schema: @schema,
        prompt_builder: @prompt_builder
      )
    end

    # Delegate to AgentRuntime::Planner
    def plan(input:, state:)
      @planner.plan(input: input, state: state)
    end

    # Delegate chat for tool-calling loops
    def chat(messages:, tools: nil, **kwargs)
      @planner.chat(messages: messages, tools: tools, model: @model, **kwargs)
    end

    # Delegate chat_raw for tool calls
    def chat_raw(messages:, tools: nil, **kwargs)
      @planner.chat_raw(messages: messages, tools: tools, model: @model, **kwargs)
    end
  end
end
