# frozen_string_literal: true

require_relative "../base"
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
        full_path = File.expand_path(path)

        raise ArgumentError, "File does not exist: #{path}" unless File.exist?(full_path)
        raise ArgumentError, "Path is not a file: #{path}" unless File.file?(full_path)

        content = File.read(full_path)

        {
          path: path,
          content: content,
          sha256: Utils::FileHash.sha256(content),
          lines: content.lines.count
        }
      end
    end
  end
end
