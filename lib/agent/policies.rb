# frozen_string_literal: true

module Agent
  # Safety policies and limits for agent execution
  module Policies
    # Maximum number of iterations before stopping
    MAX_ITERATIONS = 100

    # Maximum number of file edits per task
    MAX_FILE_EDITS = 50

    # Should stop if syntax check fails
    STOP_ON_SYNTAX_ERROR = true

    # Should stop if lint errors exceed threshold
    MAX_LINT_ERRORS = 10

    def self.should_stop?(state)
      return true if state[:iterations] >= MAX_ITERATIONS
      return true if state[:file_edits] >= MAX_FILE_EDITS
      return true if STOP_ON_SYNTAX_ERROR && state[:syntax_errors].positive?
      return true if state[:lint_errors] > MAX_LINT_ERRORS

      false
    end

    def self.can_edit_file?(path)
      # Prevent editing certain files
      protected_files = %w[Gemfile.lock package-lock.json yarn.lock]
      return false if protected_files.include?(File.basename(path))

      # Prevent editing outside project root
      project_root = File.expand_path(Dir.pwd)
      full_path = File.expand_path(path)
      full_path.start_with?(project_root)
    end
  end
end
