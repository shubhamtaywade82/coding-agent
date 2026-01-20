# frozen_string_literal: true

module Agent
  # Single-shot planner that generates task plans
  class Planner
    def initialize(client)
      @client = client
    end

    def run(task)
      prompt = <<~PROMPT
        You are a coding task planner.
        Given the task below, output a JSON plan.

        Rules:
        - Do NOT suggest writing files directly
        - Use read/search first
        - Use apply_patch for edits
        - Validate syntax after edits

        Task:
        #{task}
      PROMPT

      @client.generate(
        prompt: prompt,
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
