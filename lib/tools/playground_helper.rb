# frozen_string_literal: true

module Tools
  # Helper for restricting operations to playground directory
  module PlaygroundHelper
    PLAYGROUND_DIR = "playground"

    def self.project_root
      File.expand_path(Dir.pwd)
    end

    def self.playground_root
      File.join(project_root, PLAYGROUND_DIR)
    end

    def self.scope_to_playground(path)
      # Normalize: remove leading slash if present
      normalized = path.start_with?("/") ? path[1..] : path

      # If path already starts with playground/, use as-is
      return normalized if normalized.start_with?("#{PLAYGROUND_DIR}/")

      # Otherwise, prefix with playground/
      "#{PLAYGROUND_DIR}/#{normalized}"
    end

    def self.normalize_to_absolute(path)
      # If path is already absolute and within playground, use it as-is
      expanded = File.expand_path(path)
      if expanded.start_with?(playground_root)
        return expanded
      end

      # Scope to playground first
      scoped = scope_to_playground(path)
      # Convert to absolute path from root
      File.expand_path(scoped)
    end

    def self.validate_playground_path(full_path)
      # Ensure full_path is absolute
      absolute_path = File.expand_path(full_path)
      playground_root_path = playground_root

      unless absolute_path.start_with?(playground_root_path)
        raise ArgumentError, "Path must be within #{playground_root_path}/ directory. Got: #{absolute_path}"
      end
    end

    # Find actual file with case-insensitive matching
    # Returns the actual filename if found, or nil if not found
    def self.find_file_case_insensitive(path)
      # Normalize to absolute path first
      full_path = normalize_to_absolute(path)

      # If file exists with exact case, return it
      return full_path if File.exist?(full_path)

      # Try case-insensitive lookup
      dir = File.dirname(full_path)
      filename = File.basename(full_path)

      # If directory doesn't exist, return nil
      return nil unless Dir.exist?(dir)

      # Find files in directory with case-insensitive match
      actual_file = Dir.glob(File.join(dir, "*")).find do |f|
        File.basename(f).casecmp?(filename) && File.file?(f)
      end

      actual_file
    end
  end
end
