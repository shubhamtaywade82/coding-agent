# frozen_string_literal: true

require_relative "../base"
require_relative "../../utils/git"

module Tools
  module FS
    # Reverts all uncommitted changes using git
    class RevertLastChange < Tools::Base
      def self.name
        "revert_last_change"
      end

      def self.call(_args)
        success = Utils::Git.revert_all

        {
          reverted: success,
          status: success ? "All changes reverted" : "Revert failed"
        }
      end
    end
  end
end
