# frozen_string_literal: true

require "fileutils"
require_relative "../base"

module Tools
  module FS
    # Creates new files with safety checks
    class CreateFile < Tools::Base
      def self.name
        "create_file"
      end

      def self.call(args, _state:)
        path = args.fetch("path")
        content = args.fetch("content")
        full_path = File.expand_path(path)

        # Security: prevent directory traversal
        project_root = File.expand_path(Dir.pwd)
        raise ArgumentError, "Path outside project root" unless full_path.start_with?(project_root)

        # Fail if file exists
        raise ArgumentError, "File already exists: #{path}" if File.exist?(full_path)

        # Create directory if needed
        dir = File.dirname(full_path)
        FileUtils.mkdir_p(dir)

        # Write file
        File.write(full_path, content)

        { status: "created", path: path }
      end
    end
  end
end
