# frozen_string_literal: true

require_relative "../base"
require_relative "../playground_helper"

module Tools
  module Validation
    # Validates Ruby syntax using ruby -c
    class RubySyntaxCheck < Tools::Base
      def self.name
        "ruby_syntax_check"
      end

      def self.call(args, _state:)
        # Handle missing path with better error message
        unless args.is_a?(Hash) && args.key?("path")
          raise ArgumentError, "Missing required parameter: 'path'. Received args: #{args.inspect}"
        end
        path = args["path"]

        # Reject placeholder/fake paths (check BEFORE normalization)
        placeholder_patterns = ["/path/to/", "/home/user/", "/tmp/", "/var/"]
        if placeholder_patterns.any? { |pattern| path.include?(pattern) }
          raise ArgumentError, "Invalid placeholder path: #{path}. Use actual file paths relative to project root (e.g., 'calculator.rb', 'lib/file.rb')."
        end

        # Convert to absolute path from root, scoped to playground
        full_path = PlaygroundHelper.normalize_to_absolute(path)

        # Try case-insensitive file lookup (Linux is case-sensitive)
        unless File.exist?(full_path)
          actual_file = PlaygroundHelper.find_file_case_insensitive(path)
          if actual_file
            full_path = actual_file
          else
            # Provide helpful error message with suggestions
            dir = File.dirname(full_path)
            if Dir.exist?(dir)
              similar_files = Dir.glob(File.join(dir, "*")).select { |f| File.file?(f) }
              suggestion = similar_files.find { |f| File.basename(f).downcase == File.basename(full_path).downcase }
              if suggestion
                raise ArgumentError, "File does not exist: #{full_path}\nDid you mean: #{File.basename(suggestion)}? (case-sensitive filesystem)"
              else
                raise ArgumentError, "File does not exist: #{full_path}\nAvailable files in #{dir}: #{similar_files.map { |f| File.basename(f) }.join(', ')}"
              end
            else
              raise ArgumentError, "File does not exist: #{full_path}"
            end
          end
        end

        # Security: restrict to playground directory
        PlaygroundHelper.validate_playground_path(full_path)

        output = `ruby -c "#{full_path}" 2>&1`

        if output.include?("Syntax OK")
          { ok: true }
        else
          { ok: false, error: output }
        end
      end
    end
  end
end
