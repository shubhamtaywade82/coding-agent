# frozen_string_literal: true

require "json"

module Agent
  # Policy that validates agent decisions
  # Extends AgentRuntime::Policy with coding-agent specific rules
  class Policy < AgentRuntime::Policy
    def initialize
      super
      @recent_calls = []
    end

    def validate!(decision, state:)
      super

      # Prevent dangerous actions
      dangerous_actions = %w[delete_file rm remove]
      if dangerous_actions.include?(decision.action.to_s)
        raise AgentRuntime::PolicyViolation, "Dangerous action '#{decision.action}' is not allowed"
      end

      # Prevent repeated identical calls (anti-loop protection)
      call_signature = "#{decision.action}:#{decision.params.to_json}"

      # Allow syntax checks after edits (they're necessary for validation)
      # But still prevent infinite loops
      if decision.action.to_s == "ruby_syntax_check"
        # Allow syntax check to repeat up to 3 times (after edits, might need multiple checks)
        blocking_threshold = 3
        # Check if there was an edit between syntax checks
        recent_edits = @recent_calls.last(5).any? { |call| call.start_with?("apply_patch:") }
        if !recent_edits && @recent_calls.last(blocking_threshold).include?(call_signature)
          raise AgentRuntime::PolicyViolation, "Repeated syntax check without edits detected (#{blocking_threshold} times). If syntax check passed (ok: true), the task is complete - STOP. If it failed, fix the code with apply_patch first."
        end
      elsif decision.action.to_s == "read_file"
        # Allow read_file up to 3 times (might need to re-read after edits)
        blocking_threshold = 3
        if @recent_calls.last(blocking_threshold).include?(call_signature)
          raise AgentRuntime::PolicyViolation, "Repeated read_file call detected (#{blocking_threshold} times). You've already read this file multiple times. If you need to modify it, use apply_patch. If syntax check passed, the task is complete - STOP."
        end
      else
        # Block other operations after 2 repeats
        blocking_threshold = 2
        if @recent_calls.last(blocking_threshold).include?(call_signature)
          raise AgentRuntime::PolicyViolation, "Repeated identical call detected: #{decision.action} with same parameters (#{blocking_threshold} times). Try a different approach."
        end
      end

      # Track recent calls (keep last 5)
      @recent_calls << call_signature
      @recent_calls.shift if @recent_calls.length > 5
    end
  end
end
