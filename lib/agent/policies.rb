# frozen_string_literal: true

module Agent
  # Safety policies and limits for agent execution
  module Policies
    MAX_STEPS = 25

    def self.allow_continue?(state)
      state.steps < MAX_STEPS
    end

    def self.allow_tool?(_tool_name)
      true
    end
  end
end
