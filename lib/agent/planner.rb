# frozen_string_literal: true

module Agent
  # Single-shot planner that generates task plans
  # Uses ollama-client /generate endpoint
  # Inherits from AgentRuntime::Planner for FSM integration
  class Planner < AgentRuntime::Planner
    def initialize(client)
      super()
      @client = client
    end

    def call(input, state: nil) # rubocop:disable Lint/UnusedMethodArgument
      @client.generate(
        prompt: <<~PROMPT,
          You are a coding task planner.

          Rules:
          - Do NOT write code directly
          - Always explore files first
          - Use apply_patch for edits
          - Syntax validation is mandatory

          Task:
          #{input}

          Output a concise JSON plan.
        PROMPT
        format: {
          type: "object",
          required: ["intent"],
          properties: {
            intent: { type: "string" }
          }
        }
      )
    end
  end
end
