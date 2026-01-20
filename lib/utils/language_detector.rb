# frozen_string_literal: true

module Utils
  # Detects programming language from file extension
  class LanguageDetector
    EXTENSIONS = {
      ".rb" => "ruby",
      ".js" => "javascript",
      ".ts" => "typescript",
      ".py" => "python",
      ".go" => "go",
      ".rs" => "rust",
      ".java" => "java"
    }.freeze

    def self.detect(path)
      ext = File.extname(path)
      EXTENSIONS[ext] || "unknown"
    end
  end
end
