require "optparse"
require_relative "agent/config"

module FeatureMachine
  # The local coding agent. It runs on a developer's machine against a host
  # app's maintainer API and never loads Rails, so the engine itself does not
  # require this file; `require "feature_machine/agent"` opts in.
  module Agent
    class CLI
      USAGE = "usage: feature_machine agent [options]".freeze

      def self.start(argv = ARGV, out: $stdout, err: $stderr, env: ENV)
        new(out: out, err: err, env: env).run(argv.dup)
      end

      def initialize(out:, err:, env:)
        @out = out
        @err = err
        @env = env
      end

      def run(argv)
        command = argv.shift
        return usage(@out, 0) if command.nil? || %w[-h --help help].include?(command)
        return usage(@err, 64, "unknown command: #{command}") unless command == "agent"

        config = Config.load(flags: parse(argv), env: @env)
        @out.puts "feature_machine agent: #{config.app_url} -> #{config.checkout}"
        @out.puts "  tests: #{config.test_command}, max_steps: #{config.max_steps}"
        0
      rescue OptionParser::ParseError, Config::Invalid => e
        usage(@err, 64, e.message)
      end

      private

      # No --token flag: a token on the command line lands in shell history.
      def parse(argv)
        flags = {}
        OptionParser.new do |o|
          o.on("--app-url URL") { |v| flags["app_url"] = v }
          o.on("--checkout DIR") { |v| flags["checkout"] = v }
          o.on("--test-command CMD") { |v| flags["test_command"] = v }
          o.on("--plan-model MODEL") { |v| flags["plan_model"] = v }
          o.on("--implement-model MODEL") { |v| flags["implement_model"] = v }
          o.on("--max-steps N", Integer) { |v| flags["max_steps"] = v }
        end.parse!(argv)
        raise OptionParser::InvalidArgument, argv.join(" ") unless argv.empty?

        flags
      end

      def usage(io, status, message = nil)
        io.puts message if message
        io.puts USAGE
        status
      end
    end
  end
end
