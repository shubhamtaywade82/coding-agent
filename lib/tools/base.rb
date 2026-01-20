# frozen_string_literal: true

module Tools
  # Base class for all tools
  class Base
    def self.name
      raise NotImplementedError, "#{self} must implement .name"
    end

    def self.call(_args, _state:)
      raise NotImplementedError, "#{self} must implement .call"
    end
  end
end
