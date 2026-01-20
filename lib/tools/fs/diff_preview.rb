# frozen_string_literal: true

require_relative "../base"

module Tools
  module FS
    # Shows git diff of current changes
    class DiffPreview < Tools::Base
      def self.name
        "diff_preview"
      end

      def self.call(_, _state:)
        { diff: `git diff` }
      end
    end
  end
end
