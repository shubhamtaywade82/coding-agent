# frozen_string_literal: true

# Main entry point for CodingAgent
# Wires together ollama-client, agent_runtime, and all tools

require "ollama/client"
require "agent_runtime"

require_relative "coding/agent/version"

# Agent components
require_relative "agent/planner"
require_relative "agent/policy"
require_relative "agent/executor"

# Tool registry
require_relative "tools/index"

# Utilities
require_relative "utils/file_hash"
require_relative "utils/git"
require_relative "utils/language_detector"

# Main entry point for CodingAgent
# Wires together all tools and agent components
module CodingAgent
  class Error < StandardError; end

  # Main entry point that wires ollama-client + agent_runtime
  def self.run(task, model: "qwen2.5-coder:7b", client: nil)
    # Create Ollama client
    ollama = client || Ollama::Client.new

    # Create planner with schema and prompt builder
    planner = Agent::Planner.new(client: ollama, model: model)

    # Create policy
    policy = Agent::Policy.new

    # Create tool registry from tools
    tool_registry = Agent::Executor.build_tool_registry

    # Create executor
    executor = Agent::Executor.new(tool_registry: tool_registry)

    # Create state
    state = AgentRuntime::State.new

    # Create agent with max_iterations limit
    agent = AgentRuntime::Agent.new(
      planner: planner,
      policy: policy,
      executor: executor,
      state: state,
      max_iterations: 25
    )

    # Run the agent
    $stdout.puts "\n" + "=" * 60
    $stdout.puts "🚀 Starting Coding Agent"
    $stdout.puts "=" * 60
    $stdout.puts "Task: #{task}"
    $stdout.puts "Model: #{model}"
    $stdout.puts "Max iterations: 25"
    $stdout.puts "=" * 60 + "\n"

    begin
      agent.run(initial_input: task)
      $stdout.puts "\n" + "=" * 60
      $stdout.puts "✅ Agent completed successfully"
      $stdout.puts "=" * 60
    rescue StandardError => e
      $stdout.puts "\n" + "=" * 60
      $stdout.puts "❌ Agent failed: #{e.class} - #{e.message}"
      $stdout.puts "=" * 60
      raise
    end
  end

  # Get all available tools
  def self.tools
    Tools::ALL
  end
end
