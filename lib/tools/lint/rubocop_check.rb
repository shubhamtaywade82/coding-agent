# frozen_string_literal: true

require "English"
require_relative "../base"
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
        full_path = File.expand_path(path)

        raise ArgumentError, "File does not exist: #{path}" unless File.exist?(full_path)

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
