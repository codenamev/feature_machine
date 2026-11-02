require "ruby_llm"
require_relative "host"
require_relative "tools"

module FeatureMachine
  module Agent
    # Works one item through the host's maintainer MCP. Nothing writes back
    # to the host without approval, and every run is capped at max_steps.
    class Fulfiller < RubyLLM::Agent
      inputs :config

      model { config.plan_model }
      instructions <<~TEXT
        You fulfil work items for a Rails app. Read the item with
        get_work_item, work in the local checkout, and report progress with
        update_work_item. Stop when the item is handed off or blocked.
      TEXT
      mcp { [ Host.new(config: config) ] }
      tools { Tools.for(config) }

      Result = Struct.new(:status, :steps, :pending, :error, keyword_init: true)

      # Provider hiccups worth waiting out. Anything else (bad request, auth,
      # billing, context length) fails the run on the first hit.
      TRANSIENT = [
        RubyLLM::RateLimitError, RubyLLM::ServerError,
        RubyLLM::ServiceUnavailableError, RubyLLM::OverloadedError
      ].freeze

      # Stages the item and advances one move at a time. It returns :done,
      # :awaiting_approval (with the pending tool calls), :step_limit, or
      # :failed (with the error). The caller decides, then calls resume.
      #
      # The first step is the plan turn on plan_model. Pass implement_model
      # and every step after it runs there instead.
      def self.run(chat, item_id:, max_steps:, implement_model: nil, **opts)
        chat.ask_later("Fulfil work item #{item_id}.")
        return resume(chat, max_steps: max_steps, **opts) unless implement_model

        planned = resume(chat, max_steps: [ max_steps, 1 ].min, **opts)
        # A plan that paused for approval still hands off: resume picks up
        # on implement_model.
        chat.with_model(implement_model) if %i[step_limit awaiting_approval].include?(planned.status)
        return planned unless planned.status == :step_limit && max_steps > 1

        rest = resume(chat, max_steps: max_steps - 1, **opts)
        rest.steps += planned.steps
        rest
      end

      def self.resume(chat, max_steps:, retries: 3, sleeper: ->(s) { sleep(s) })
        steps = 0
        loop do
          return Result.new(status: :done, steps: steps, pending: []) if chat.complete?
          return Result.new(status: :awaiting_approval, steps: steps, pending: chat.pending_approvals) if chat.waiting?
          return Result.new(status: :step_limit, steps: steps, pending: []) if steps >= max_steps

          failure = step_with_retries(chat, retries, sleeper)
          return Result.new(status: :failed, steps: steps, pending: [], error: failure) if failure
          steps += 1
        end
      end

      # A retried step doesn't count against max_steps. Returns the error
      # that ended the run, or nil.
      def self.step_with_retries(chat, retries, sleeper)
        attempt = 0
        begin
          chat.step
          nil
        rescue *TRANSIENT => e
          return e if (attempt += 1) > retries
          sleeper.call(2**attempt)
          retry
        rescue RubyLLM::Error => e
          e
        end
      end
      private_class_method :step_with_retries
    end
  end
end
