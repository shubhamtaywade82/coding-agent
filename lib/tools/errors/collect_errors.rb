# frozen_string_literal: true

require_relative "../base"

module Tools
  module Errors
    # Collects errors from validation and linting
    class CollectErrors < Tools::Base
      def self.name
        "collect_errors"
      end

      def self.call(_, _state:)
        errors = []

        # Collect syntax errors from recent validation runs
        # This is a placeholder - in a real implementation, this would
        # track errors from validation tools
        # For now, we'll return an empty array

        {
          errors: errors,
          count: errors.count
        }
      end
    end
  end
end
