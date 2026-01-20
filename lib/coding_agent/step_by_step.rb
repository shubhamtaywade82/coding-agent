# frozen_string_literal: true

require "json"
require "ostruct"
require "ollama/client"
require "agent_runtime"

# Require agent components
require_relative "../agent/planner"
require_relative "../agent/policy"
require_relative "../agent/executor"
require_relative "../tools/index"

# Step-by-step execution helper for debugging and learning
module CodingAgent
  class StepByStep
    def initialize(task, model: "qwen2.5-coder", client: nil)
      @task = task
      @model = model
      @client = client || Ollama::Client.new

      # Create components (same as CodingAgent.run)
      @planner = Agent::Planner.new(client: @client, model: @model)
      @policy = Agent::Policy.new
      @tool_registry = Agent::Executor.build_tool_registry
      @executor = Agent::Executor.new(tool_registry: @tool_registry)
      @state = AgentRuntime::State.new

      # Create agent but we'll control it manually
      @agent = AgentRuntime::Agent.new(
        planner: @planner,
        policy: @policy,
        executor: @executor,
        state: @state,
        max_iterations: 25
      )

      @step_count = 0
      @last_decision = nil
      @tool_results = []  # Track tool results for building messages
    end

    def build_messages_from_state
      messages = [
        { role: "user", content: @task }
      ]

      # Add tool results as observations
      @tool_results.each do |result|
        messages << {
          role: "tool",
          content: "Tool: #{result[:tool]}\nResult: #{JSON.pretty_generate(result[:result])}"
        }
      end

      messages
    end

    def run_step
      @step_count += 1

      puts "\n" + "=" * 80
      puts "STEP #{@step_count}"
      puts "=" * 80

      # Get decision from agent (this handles planner vs executor logic)
      puts "\n🤖 Getting decision from agent..."

      begin
        # The agent's internal logic will use planner for first step, executor for rest
        decision = if @step_count == 1
                     puts "   📋 Using PLANNER (first decision)..."
                     @planner.plan(input: @task, state: @state)
                   else
                     puts "   🔄 Using PLANNER.chat_raw (subsequent decisions)..."
                     # For subsequent steps, use chat_raw to get raw response
                     # Then manually parse tool calls or JSON decision
                     messages = build_messages_from_state
                     tools = @tool_registry.tool_schemas

                     # Use chat_raw to get raw response (handles both JSON and tool calls)
                     raw_response = @planner.chat_raw(messages: messages, tools: tools)

                     # Try to parse as JSON decision first
                     begin
                       parsed = JSON.parse(raw_response)
                       # If it's a hash with action/params, use it
                       if parsed.is_a?(Hash) && parsed.key?("action")
                         parsed
                       else
                         # Might be a tool call, try to extract decision from it
                         # For now, just return the parsed hash
                         parsed
                       end
                     rescue JSON::ParserError
                       # If not JSON, try to extract tool call or decision from text
                       # For debugging, show the raw response
                       puts "   ⚠️  Raw response (not JSON): #{raw_response[0..200]}..."
                       # Try to find JSON in the response
                       json_match = raw_response.match(/\{[\s\S]*\}/)
                       if json_match
                         JSON.parse(json_match[0])
                       else
                         raise "Could not parse decision from LLM response: #{raw_response[0..200]}"
                       end
                     end
                   end

        @last_decision = decision

        # Handle both Decision objects and Hashes/strings from chat
        if decision.is_a?(Hash)
          puts "\n🤖 LLM Decision (from chat):"
          puts "   Action: #{decision['action'] || decision[:action] || 'unknown'}"
          puts "   Params: #{JSON.pretty_generate(decision['params'] || decision[:params] || {})}"
          puts "   Confidence: #{decision['confidence'] || decision[:confidence] || 'N/A'}"

          # Convert hash to decision-like object for policy and execution
          decision_obj = OpenStruct.new(
            action: (decision['action'] || decision[:action]).to_s,
            params: decision['params'] || decision[:params] || {},
            confidence: decision['confidence'] || decision[:confidence]
          )
          decision = decision_obj
        elsif decision.is_a?(String)
          # Chat might return JSON string, parse it
          begin
            parsed = JSON.parse(decision)
            puts "\n🤖 LLM Decision (parsed from JSON):"
            puts "   Action: #{parsed['action'] || 'unknown'}"
            puts "   Params: #{JSON.pretty_generate(parsed['params'] || {})}"
            puts "   Confidence: #{parsed['confidence'] || 'N/A'}"

            decision_obj = OpenStruct.new(
              action: (parsed['action'] || '').to_s,
              params: parsed['params'] || {},
              confidence: parsed['confidence']
            )
            decision = decision_obj
          rescue JSON::ParserError
            puts "\n⚠️  Warning: Could not parse decision as JSON: #{decision[0..100]}"
            raise "Invalid decision format from LLM"
          end
        else
          puts "\n🤖 LLM Decision:"
          puts "   Action: #{decision.action}"
          puts "   Params: #{JSON.pretty_generate(decision.params)}"
          puts "   Confidence: #{decision.respond_to?(:confidence) ? decision.confidence : "N/A"}"
        end

        # Validate with policy
        puts "\n🛡️  Policy Validation..."
        begin
          @policy.validate!(decision, state: @state)
          puts "   ✅ Decision validated"
        rescue AgentRuntime::PolicyViolation => e
          puts "   ❌ Policy violation: #{e.message}"
          raise
        end

        # Execute tool via executor (which handles tool registry lookup)
        action = decision.respond_to?(:action) ? decision.action : (decision['action'] || decision[:action])
        params = decision.respond_to?(:params) ? decision.params : (decision['params'] || decision[:params] || {})

        puts "\n🔧 Executing Tool: #{action}"

        # Create a decision-like object for executor
        exec_decision = OpenStruct.new(action: action, params: params)
        result = @executor.execute(exec_decision, state: @state)

        # Track tool result for next iteration
        @tool_results << { tool: action, result: result }

        puts "\n📊 Tool Result:"
        if result.is_a?(Hash)
          # Pretty print result, truncate long content
          display_result = result.dup
          if display_result["content"] && display_result["content"].length > 200
            display_result["content"] = "#{display_result["content"][0..200]}... (#{display_result["content"].length} chars)"
          end
          puts JSON.pretty_generate(display_result)
        else
          puts result.inspect
        end

        puts "\n📝 State updated:"
        puts "   Steps executed: #{@step_count}"
        # Note: State observations are managed internally by agent_runtime

        result
      rescue StandardError => e
        puts "\n❌ Error: #{e.class} - #{e.message}"
        puts "   Backtrace:"
        puts e.backtrace.first(5).map { |l| "      #{l}" }.join("\n")
        raise
      end
    end

    def run_all(max_steps: 25)
      puts "\n" + "=" * 80
      puts "🚀 Starting Step-by-Step Execution"
      puts "=" * 80
      puts "Task: #{@task}"
      puts "Model: #{@model}"
      puts "Max steps: #{max_steps}"
      puts "=" * 80

      loop do
        break if @step_count >= max_steps

        result = run_step

        # Check if task is complete (syntax check passed)
        if result.is_a?(Hash) && result["ok"] == true && @last_decision&.action.to_s == "ruby_syntax_check"
          puts "\n✅ Syntax check passed - Task appears complete!"
          puts "Press Enter to continue or type 'stop' to exit"
          input = $stdin.gets.chomp
          break if input.downcase == "stop"
        end

        puts "\nPress Enter to continue to next step, or type 'stop' to exit..."
        input = $stdin.gets.chomp
        break if input.downcase == "stop"
      end

      puts "\n" + "=" * 80
      puts "🏁 Execution Complete"
      puts "=" * 80
      puts "Total steps: #{@step_count}"
    end

    def inspect_state
      puts "\n" + "=" * 80
      puts "📊 Current State"
      puts "=" * 80
      puts "Steps executed: #{@step_count}"
      puts "Last decision: #{@last_decision&.action || 'none'}"
      puts "State object: #{@state.class.name}"
      puts "\nNote: Detailed observations are managed internally by agent_runtime"
    end
  end
end
