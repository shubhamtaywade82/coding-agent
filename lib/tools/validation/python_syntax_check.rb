# frozen_string_literal: true

require "English"
require_relative "../base"

module Tools
  module Validation
    # Validates Python syntax using py_compile
    class PythonSyntaxCheck < Tools::Base
      def self.name
        "python_syntax_check"
      end

      def self.call(args)
        path = args.fetch("path")
        full_path = File.expand_path(path)

        raise ArgumentError, "File does not exist: #{path}" unless File.exist?(full_path)

        output = `python3 -m py_compile "#{full_path}" 2>&1`
        exit_code = $CHILD_STATUS.exitstatus

        if exit_code.zero?
          { ok: true, message: "Syntax OK" }
        else
          { ok: false, error: output.chomp }
        end
      end
    end
  end
end
