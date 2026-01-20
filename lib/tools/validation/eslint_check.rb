# frozen_string_literal: true

require "English"
require_relative "../base"
require "json"

module Tools
  module Validation
    # Validates JavaScript/TypeScript syntax using eslint
    class EslintCheck < Tools::Base
      def self.name
        "eslint_check"
      end

      def self.call(args)
        path = args.fetch("path")
        full_path = File.expand_path(path)

        raise ArgumentError, "File does not exist: #{path}" unless File.exist?(full_path)

        # Check if eslint is available
        return { ok: false, error: "eslint not found in PATH" } unless system("which eslint > /dev/null 2>&1")

        output = `eslint --format json "#{full_path}" 2>&1`
        $CHILD_STATUS.exitstatus

        begin
          result = JSON.parse(output)
          errors = result.first&.dig("messages") || []

          if errors.empty?
            { ok: true, message: "No syntax errors" }
          else
            { ok: false, errors: errors, formatted: output }
          end
        rescue JSON::ParserError
          { ok: false, error: output.chomp }
        end
      end
    end
  end
end
