require "open3"
require "tmpdir"
require_relative "config"
require_relative "fulfiller"

module FeatureMachine
  module Agent
    # The runner Evaluation calls for a live run: seed one work item, run the
    # Fulfiller on a throwaway clone of the checkout, and report which tool
    # calls actually went through.
    #
    # The maintainer API can read and update items but not create them, so
    # seeding is the caller's: inside the dummy app it is a WorkItem.create!.
    #
    #   Evaluation.runner = LiveRunner.new(config: Config.load, seed: ->(input) { ... })
    class LiveRunner
      def initialize(config:, seed:, fulfil: Fulfiller.method(:run), chat: ->(c) { Fulfiller.chat(config: c) })
        @config = config
        @seed = seed
        @fulfil = fulfil
        @chat = chat
      end

      def call(input)
        item_id = @seed.call(input)
        Dir.mktmpdir("feature_machine-eval") do |dir|
          clone_into(dir)
          config = scratch_config(dir)
          chat = @chat.call(config)
          completed = track_completed(chat)
          result = @fulfil.call(chat, item_id: item_id, max_steps: config.max_steps, implement_model: config.implement_model)
          { result: result, completed: completed }
        end
      end

      private

      def clone_into(dir)
        _out, err, status = Open3.capture3("git", "clone", "--quiet", "--local", @config.checkout, dir)
        raise ArgumentError, "could not clone #{@config.checkout}: #{err.strip}" unless status.success?
      end

      def scratch_config(dir)
        Config.new(app_url: @config.app_url, token: @config.token, checkout: dir,
                   test_command: @config.test_command, plan_model: @config.plan_model,
                   implement_model: @config.implement_model, max_steps: @config.max_steps)
      end

      # after_tool_result only sees the result, so the name comes from the
      # matching before_tool_call. Thread#[] is fiber-local, which keeps the
      # pairing right when tools run concurrently. A refusal comes back as
      # { "error" => ... } and doesn't count.
      def track_completed(chat)
        completed = []
        chat.before_tool_call { |call| Thread.current[:feature_machine_eval_tool] = call.name }
        chat.after_tool_result do |result|
          name = Thread.current[:feature_machine_eval_tool]
          completed << name if name && !(result.is_a?(Hash) && result.key?("error"))
        end
        completed
      end
    end
  end
end
