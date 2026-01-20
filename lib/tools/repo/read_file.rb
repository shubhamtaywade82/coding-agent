# frozen_string_literal: true

require_relative "../base"
require_relative "../playground_helper"
require_relative "../../utils/file_hash"

module Tools
  module Repo
    # Reads file content with hash for validation
    class ReadFile < Tools::Base
      def self.name
        "read_file"
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
        raise ArgumentError, "Path is not a file: #{full_path}" unless File.file?(full_path)

        content = File.read(full_path)

        {
          path: full_path,
          content: content,
          sha256: Utils::FileHash.sha256(content),
          lines: content.lines.count
        }
      end
    end
  end
end
