# frozen_string_literal: true

require "pathname"
require_relative "../base"

module Tools
  module Repo
    # Searches for text in repository files
    class Search < Tools::Base
      EXCLUDED_PATTERNS = %w[.git node_modules vendor bundle .bundle tmp log].freeze

      def self.name
        "search"
      end

      def self.call(args)
        query = args.fetch("query")
        path = args.fetch("path", ".")
        case_sensitive = args.fetch("case_sensitive", false)

        full_path = File.expand_path(path)
        results = []

        Dir.glob(File.join(full_path, "**/*"), File::FNM_DOTMATCH).each do |file_path|
          next unless File.file?(file_path)
          next if excluded?(file_path)

          begin
            File.readlines(file_path).each_with_index do |line, index|
              line_number = index + 1
              next unless case_sensitive ? line.include?(query) : line.downcase.include?(query.downcase)

              relative_path = Pathname.new(file_path).relative_path_from(Pathname.new(Dir.pwd)).to_s
              results << {
                file: relative_path,
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
