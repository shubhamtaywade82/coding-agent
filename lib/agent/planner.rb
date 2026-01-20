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

          Output a JSON plan describing:
          - what files to inspect
          - what edits are needed (high level)

          Rules:
          - Never suggest writing files directly
          - All edits must use apply_patch
          - Validation is mandatory

          Task:
          #{input}
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
