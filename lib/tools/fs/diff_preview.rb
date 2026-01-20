# frozen_string_literal: true

require_relative "../base"
require_relative "../../utils/git"

module Tools
  module FS
    # Shows git diff of current changes
    class DiffPreview < Tools::Base
      def self.name
        "diff_preview"
      end

      def self.call(_args)
        diff = Utils::Git.diff
        status = Utils::Git.status

        {
          diff: diff,
          status: status,
          has_changes: !diff.empty?
        }
      end
    end
  end
end
