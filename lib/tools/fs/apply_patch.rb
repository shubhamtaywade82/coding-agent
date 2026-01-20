# frozen_string_literal: true

require_relative "../base"
require_relative "../../utils/file_hash"

module Tools
  module FS
    # Applies patch-based edits to files with hash validation
    class ApplyPatch < Tools::Base
      def self.name
        "apply_patch"
      end

      def self.call(args)
        path = args.fetch("path")
        edits = args.fetch("edits")
        expected_hash = args.fetch("sha256")

        full_path = File.expand_path(path)
        raise ArgumentError, "File does not exist: #{path}" unless File.exist?(full_path)

        original = File.read(full_path)
        actual_hash = Utils::FileHash.sha256(original)

        unless actual_hash == expected_hash
          raise ArgumentError, "File changed since read. Expected #{expected_hash}, got #{actual_hash}"
        end

        lines = original.lines

        # Apply edits in reverse order to preserve line numbers
        edits.sort_by { |e| -e["start_line"] }.each do |edit|
          start_line = edit["start_line"] - 1 # Convert to 0-based index
          end_line = edit["end_line"] - 1
          replacement = edit["replacement"]

          # Validate line numbers
          if start_line.negative? || end_line >= lines.length || start_line > end_line
            raise ArgumentError,
                  "Invalid line range: #{start_line + 1}..#{end_line + 1}"
          end

          # Replace lines
          lines[start_line..end_line] = replacement.lines
        end

        # Write atomically
        File.write(full_path, lines.join)

        { status: "patched", path: path }
      end
    end
  end
end
