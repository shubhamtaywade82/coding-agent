# frozen_string_literal: true

# Main entry point for CodingAgent
# This file wires together all tools and agent components

require_relative "coding/agent/version"

# Agent components
require_relative "agent/planner"
require_relative "agent/executor"
require_relative "agent/policies"

# Repository exploration tools
require_relative "tools/repo/list_files"
require_relative "tools/repo/read_file"
require_relative "tools/repo/search"

# File system tools
require_relative "tools/fs/create_file"
require_relative "tools/fs/apply_patch"
require_relative "tools/fs/diff_preview"
require_relative "tools/fs/revert_last_change"

# Validation tools
require_relative "tools/validation/ruby_syntax_check"
require_relative "tools/validation/python_syntax_check"
require_relative "tools/validation/eslint_check"

# Linting tools
require_relative "tools/lint/rubocop_check"

# Error collection
require_relative "tools/errors/collect_errors"

# Utilities
require_relative "utils/file_hash"
require_relative "utils/git"
require_relative "utils/language_detector"

# Main entry point for CodingAgent
# Wires together all tools and agent components
module CodingAgent
  class Error < StandardError; end

  # Tool registry - all available tools
  TOOLS = [
    Tools::Repo::ListFiles,
    Tools::Repo::ReadFile,
    Tools::Repo::Search,
    Tools::FS::CreateFile,
    Tools::FS::ApplyPatch,
    Tools::FS::DiffPreview,
    Tools::FS::RevertLastChange,
    Tools::Validation::RubySyntaxCheck,
    Tools::Validation::PythonSyntaxCheck,
    Tools::Validation::EslintCheck,
    Tools::Lint::RubocopCheck,
    Tools::Errors::CollectErrors
  ].freeze

  # Main entry point
  # This expects an agent_runtime to be provided externally
  # For now, this is a placeholder that shows the structure
  def self.run(task, client: nil, runtime: nil)
    raise Error, "Client or runtime must be provided" if client.nil? && runtime.nil?

    # If runtime is provided, use it directly
    if runtime
      runtime.run(task)
      return
    end

    # Otherwise, create planner and executor with client
    planner = Agent::Planner.new(client)
    executor = Agent::Executor.new(client)

    # NOTE: In a real implementation, you would wire this to agent_runtime
    # For now, we just return the components
    {
      planner: planner,
      executor: executor,
      tools: TOOLS,
      policies: Agent::Policies
    }
  end

  # Get all available tools
  def self.tools
    TOOLS
  end
end
