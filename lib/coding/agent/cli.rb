# frozen_string_literal: true

module Coding
  module Agent
    # Command-line interface for the coding-agent gem
    class CLI
      def self.run(argv = ARGV)
        new.run(argv)
      end

      def run(argv)
        case argv.first
        when "--version", "-v"
          puts "coding-agent #{Coding::Agent::VERSION}"
        else
          show_help
        end
      end

      private

      def show_help
        puts <<~HELP
          coding-agent #{Coding::Agent::VERSION}

          Usage: coding-agent [options]

          Options:
            -v, --version    Show version number
            -h, --help       Show this help message
        HELP
      end
    end
  end
end
