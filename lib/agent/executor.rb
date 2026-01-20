# frozen_string_literal: true

module Agent
  # Executor that handles chat-based tool calling loop
  class Executor
    def initialize(client)
      @client = client
    end

    def step(messages)
      @client.chat(messages: messages)
    end
  end
end
