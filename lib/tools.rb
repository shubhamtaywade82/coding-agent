# frozen_string_literal: true

# Tool registry - all available tools
require_relative "tools/repo/list_files"
require_relative "tools/repo/read_file"
require_relative "tools/repo/search"

require_relative "tools/fs/create_file"
require_relative "tools/fs/apply_patch"
require_relative "tools/fs/diff_preview"
require_relative "tools/fs/revert_last_change"

require_relative "tools/validation/ruby_syntax_check"
require_relative "tools/validation/python_syntax_check"
require_relative "tools/validation/eslint_check"

require_relative "tools/lint/rubocop_check"

require_relative "tools/errors/collect_errors"

module Tools
  # All available tools
  ALL = [
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
end
