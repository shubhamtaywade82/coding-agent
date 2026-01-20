# frozen_string_literal: true

require_relative "../base"
require_relative "../../utils/file_hash"

module Tools
  module FS
    # Applies patch-based edits to files with hash validation
    class ApplyPatch < Tools::Base
      def self.name
        "apply_patch"
      end

      def self.call(args, _state:)
        path = args.fetch("path")
        edits = args.fetch("edits")
        expected = args.fetch("sha256")

        original = File.read(path)
        raise "File changed since read" unless
          Utils::FileHash.sha256(original) == expected

        lines = original.lines

        edits.each do |e|
          lines[(e["start_line"] - 1)...e["end_line"]] =
            e["replacement"].lines
        end

        File.write(path, lines.join)
        { status: "patched" }
      end
    end
  end
end
