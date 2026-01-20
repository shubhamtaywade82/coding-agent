# frozen_string_literal: true

require_relative "../base"

module Tools
  module Validation
    # Validates Ruby syntax using ruby -c
    class RubySyntaxCheck < Tools::Base
      def self.name
        "ruby_syntax_check"
      end

      def self.call(args, _state:)
        path = args.fetch("path")
        output = `ruby -c #{path} 2>&1`

        if output.include?("Syntax OK")
          { ok: true }
        else
          { ok: false, error: output }
        end
      end
    end
  end
end
