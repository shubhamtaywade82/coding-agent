# frozen_string_literal: true

# Main entry point for CodingAgent
# Wires together ollama-client, agent_runtime, and all tools

require "ollama/client"
require "agent_runtime"

require_relative "coding/agent/version"

# Agent components
require_relative "agent/planner"
require_relative "agent/executor"
require_relative "agent/policies"

# Tool registry
require_relative "tools"

# Utilities
require_relative "utils/file_hash"
require_relative "utils/git"
require_relative "utils/language_detector"

# Main entry point for CodingAgent
# Wires together all tools and agent components
module CodingAgent
  class Error < StandardError; end

  # Main entry point that wires ollama-client + agent_runtime
  def self.run(task, model: "qwen2.5-coder", client: nil)
    # Create Ollama client
    ollama = client || Ollama::Client.new(model: model)

    # Create planner and executor (they use ollama-client)
    planner = Agent::Planner.new(ollama)
    executor = Agent::Executor.new(ollama)

    # Wire everything through agent_runtime
    # The runtime owns the FSM, loop, and tool orchestration
    AgentRuntime::Runner.new(
      planner: planner,
      executor: executor,
      tools: Tools::ALL,
      policies: Agent::Policies
    ).run(task)
  end

  # Get all available tools
  def self.tools
    Tools::ALL
  end
end
