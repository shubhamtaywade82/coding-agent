# frozen_string_literal: true

module Utils
  # Git operations utility
  class Git
    def self.diff
      `git diff`.chomp
    end

    def self.revert_all
      system("git checkout -- .")
    end

    def self.status
      `git status --porcelain`.chomp
    end
  end
end
