# frozen_string_literal: true

require_relative "base"

require_relative "repo/list_files"
require_relative "repo/read_file"
require_relative "repo/search"

require_relative "fs/create_file"
require_relative "fs/apply_patch"
require_relative "fs/diff_preview"
require_relative "fs/revert_last_change"

require_relative "validation/ruby_syntax_check"
require_relative "lint/rubocop_check"
require_relative "errors/collect_errors"

module Tools
  ALL = [
    Repo::ListFiles,
    Repo::ReadFile,
    Repo::Search,
    FS::CreateFile,
    FS::ApplyPatch,
    FS::DiffPreview,
    FS::RevertLastChange,
    Validation::RubySyntaxCheck,
    Lint::RubocopCheck,
    Errors::CollectErrors
  ].freeze
end
