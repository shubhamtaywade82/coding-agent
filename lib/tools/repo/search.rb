# frozen_string_literal: true

require "pathname"
require_relative "../base"
require_relative "../playground_helper"

module Tools
  module Repo
    # Searches for text in repository files
    class Search < Tools::Base
      EXCLUDED_PATTERNS = %w[.git node_modules vendor bundle .bundle tmp log].freeze

      def self.name
        "search"
      end

      def self.call(args, _state:)
        query = args.fetch("query")
        # Default to playground directory
        path = args.fetch("path", PlaygroundHelper::PLAYGROUND_DIR)
        case_sensitive = args.fetch("case_sensitive", false)

        # Convert to absolute path from root, scoped to playground
        base_path = if path == "."
                      PlaygroundHelper.playground_root
                    else
                      PlaygroundHelper.normalize_to_absolute(path)
                    end

        # Ensure we're in playground
        PlaygroundHelper.validate_playground_path(base_path)
        results = []

        Dir.glob(File.join(base_path, "**/*"), File::FNM_DOTMATCH).each do |file_path|
          next unless File.file?(file_path)
          next if excluded?(file_path)

          begin
            File.readlines(file_path).each_with_index do |line, index|
              line_number = index + 1
              next unless case_sensitive ? line.include?(query) : line.downcase.include?(query.downcase)

              absolute_path = File.expand_path(file_path)
              results << {
                file: absolute_path,
                line: line_number,
                content: line.chomp
              }
            end
          rescue StandardError => e
            # Skip binary files or unreadable files
            next if e.is_a?(ArgumentError)
          end
        end

        { results: results, count: results.count }
      end

      def self.excluded?(path)
        EXCLUDED_PATTERNS.any? { |pattern| path.include?(pattern) }
      end
    end
  end
end
