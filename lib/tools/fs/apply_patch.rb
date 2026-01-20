# frozen_string_literal: true

require_relative "../base"
require_relative "../playground_helper"
require_relative "../../utils/file_hash"

module Tools
  module FS
    # Applies patch-based edits to files with hash validation
    class ApplyPatch < Tools::Base
      def self.name
        "apply_patch"
      end

      def self.validate_edits_format(edits)
        unless edits.is_a?(Array)
          example = '{"edits": [{"start_line": 1, "end_line": 5, "replacement": "new code\\n"}]}'
          raise ArgumentError, "edits must be an array, got #{edits.class}. Example format: #{example}"
        end

        if edits.empty?
          raise ArgumentError, "edits array cannot be empty. Provide at least one edit with start_line, end_line, and replacement."
        end

        edits.each_with_index do |edit, index|
          unless edit.is_a?(Hash)
            example = '{"start_line": 1, "end_line": 5, "replacement": "new code\\n"}'
            raise ArgumentError, "edit at index #{index} must be a hash with start_line, end_line, and replacement keys, got #{edit.class}. Example: #{example}"
          end

          # Normalize keys to strings (handle both symbol and string keys)
          normalized_edit = edit.transform_keys(&:to_s)

          required_keys = %w[start_line end_line replacement]
          missing_keys = required_keys - normalized_edit.keys
          unless missing_keys.empty?
            raise ArgumentError, "edit at index #{index} missing required keys: #{missing_keys.join(', ')}"
          end

          unless normalized_edit["start_line"].is_a?(Integer) && normalized_edit["start_line"] > 0
            raise ArgumentError, "edit at index #{index}: start_line must be a positive integer, got #{normalized_edit['start_line'].inspect}"
          end

          unless normalized_edit["end_line"].is_a?(Integer) && normalized_edit["end_line"] >= normalized_edit["start_line"]
            raise ArgumentError, "edit at index #{index}: end_line must be an integer >= start_line, got #{normalized_edit['end_line'].inspect}"
          end

          unless normalized_edit["replacement"].is_a?(String)
            raise ArgumentError, "edit at index #{index}: replacement must be a string, got #{normalized_edit['replacement'].class}"
          end

          # Store normalized edit back for use in the actual patch application
          edit.replace(normalized_edit)
        end
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

        edits = args.fetch("edits")
        expected = args["sha256"]

        validate_edits_format(edits)

        original = File.read(full_path)
        if expected
          raise "File changed since read" unless
            Utils::FileHash.sha256(original) == expected
        end

        lines = original.lines

        edits.each do |e|
          start_line = e.fetch("start_line")
          end_line = e.fetch("end_line")
          replacement = e.fetch("replacement")

          lines[(start_line - 1)...end_line] = replacement.lines
        end

        File.write(full_path, lines.join)
        { status: "patched" }
      end
    end
  end
end
