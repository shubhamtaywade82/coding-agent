# frozen_string_literal: true

require "English"
require_relative "../base"
require_relative "../playground_helper"
require "json"

module Tools
  module Lint
    # Checks Ruby code style using RuboCop
    class RubocopCheck < Tools::Base
      def self.name
        "rubocop_check"
      end

      def self.call(args, _state:)
        path = args.fetch("path")

        # Convert to absolute path from root, scoped to playground
        full_path = PlaygroundHelper.normalize_to_absolute(path)

        # Try case-insensitive file lookup (Linux is case-sensitive)
        unless File.exist?(full_path)
          actual_file = PlaygroundHelper.find_file_case_insensitive(path)
          if actual_file
            full_path = actual_file
          else
            raise ArgumentError, "File does not exist: #{full_path}"
          end
        end

        # Security: restrict to playground directory
        PlaygroundHelper.validate_playground_path(full_path)

        # Check if rubocop is available
        return { ok: false, error: "rubocop not found in PATH" } unless system("which rubocop > /dev/null 2>&1")

        output = `rubocop --format json "#{full_path}" 2>&1`
        $CHILD_STATUS.exitstatus

        begin
          result = JSON.parse(output)
          files = result["files"] || []
          offenses = files.flat_map { |f| f["offenses"] || [] }

          if offenses.empty?
            { ok: true, message: "No offenses found", offenses: [] }
          else
            {
              ok: false,
              offenses: offenses,
              summary: result["summary"] || {}
            }
          end
        rescue JSON::ParserError
          { ok: false, error: output.chomp }
        end
      end
    end
  end
end
