# frozen_string_literal: true

require "fileutils"
require_relative "../base"
require_relative "../playground_helper"

module Tools
  module FS
    # Creates new files with safety checks
    class CreateFile < Tools::Base
      def self.name
        "create_file"
      end

      def self.call(args, _state:)
        path = args.fetch("path")
        content = args.fetch("content") do
          raise ArgumentError, "Missing required parameter: 'content'. create_file requires both 'path' and 'content'. If the file already exists, use apply_patch instead."
        end

        # Convert to absolute path from root, scoped to playground
        full_path = PlaygroundHelper.normalize_to_absolute(path)

        # Security: restrict to playground directory
        PlaygroundHelper.validate_playground_path(full_path)

        # Fail if file exists
        raise ArgumentError, "File already exists: #{full_path}" if File.exist?(full_path)

        # Create directory if needed
        dir = File.dirname(full_path)
        FileUtils.mkdir_p(dir)

        # Write file
        File.write(full_path, content)

        { status: "created", path: full_path }
      end
    end
  end
end
