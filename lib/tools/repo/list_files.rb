# frozen_string_literal: true

require "pathname"
require_relative "../base"
require_relative "../playground_helper"

module Tools
  module Repo
    # Lists files in repository with glob support
    class ListFiles < Tools::Base
      EXCLUDED_PATTERNS = %w[.git node_modules vendor bundle .bundle tmp log].freeze

      def self.name
        "list_files"
      end

      def self.call(args, _state:)
        # Default to playground directory
        path = args.fetch("path", PlaygroundHelper::PLAYGROUND_DIR)
        glob = args.fetch("glob", "**/*")

        # Convert to absolute path from root, scoped to playground
        base_path = if path == "."
                      PlaygroundHelper.playground_root
                    else
                      PlaygroundHelper.normalize_to_absolute(path)
                    end

        # Ensure the base directory is in playground
        PlaygroundHelper.validate_playground_path(base_path)
        pattern = File.join(base_path, glob)

        files = Dir.glob(pattern, File::FNM_DOTMATCH)
                   .select { |f| File.file?(f) }
                   .reject { |f| excluded?(f) }
                   .map { |f| File.expand_path(f) }
                   .sort

        # Return both absolute and relative paths for clarity
        relative_files = files.map { |f| f.sub(/#{Regexp.escape(PlaygroundHelper.playground_root)}\/?/, "") }

        { files: files, relative_files: relative_files, count: files.count }
      end

      def self.excluded?(path)
        EXCLUDED_PATTERNS.any? { |pattern| path.include?(pattern) }
      end
    end
  end
end
