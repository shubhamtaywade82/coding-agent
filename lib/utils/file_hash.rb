# frozen_string_literal: true

require "digest"

module Utils
  # Utility for computing file hashes
  class FileHash
    def self.sha256(content)
      Digest::SHA256.hexdigest(content)
    end
  end
end
