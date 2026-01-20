# frozen_string_literal: true

require "pathname"
require_relative "../base"

module Tools
  module Repo
    # Lists files in repository with glob support
    class ListFiles < Tools::Base
      EXCLUDED_PATTERNS = %w[.git node_modules vendor bundle .bundle tmp log].freeze

      def self.name
        "list_files"
      end

      def self.call(args)
        path = args.fetch("path", ".")
        glob = args.fetch("glob", "**/*")

        full_path = File.expand_path(path)
        pattern = File.join(full_path, glob)

        files = Dir.glob(pattern, File::FNM_DOTMATCH)
                   .select { |f| File.file?(f) }
                   .reject { |f| excluded?(f) }
                   .map { |f| Pathname.new(f).relative_path_from(Pathname.new(Dir.pwd)).to_s }
                   .sort

        { files: files }
      end

      def self.excluded?(path)
        EXCLUDED_PATTERNS.any? { |pattern| path.include?(pattern) }
      end
    end
  end
end
