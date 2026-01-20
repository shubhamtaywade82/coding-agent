# frozen_string_literal: true

module Agent
  # Executor that handles chat-based tool calling loop
  # Uses ollama-client /chat endpoint
  # Inherits from AgentRuntime::Executor for FSM integration
  class Executor < AgentRuntime::Executor
    def initialize(client)
      super()
      @client = client
    end

    def step(messages, state: nil)
      @client.chat(
        messages: messages,
        tools: state.tools
      )
    end
  end
end
