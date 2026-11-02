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
        You fulfil one work item for a Rails app, in a local checkout.

        1. Read the item with get_work_item. If it has no acceptance
           criteria, change nothing: report it blocked and stop.
        2. Find your way around with list_files. Make the change, add or
           update tests for it, and run them with run_tests until they pass.
           Then run the whole suite.
        3. Hand it off with open_pull_request.

        Every run ends in exactly one of two ways: open_pull_request, or
        update_work_item with a progress_note that starts "Blocked:" and
        says why (no criteria, criteria you can't meet, a red suite, a
        refused pull request). Never end on a reply alone.

        Every progress_note is public: users read it on the roadmap. Write
        it in plain words for them, in a sentence or two, with no class
        names, file paths or error output. Technical detail belongs in the
        pull request.
      TEXT
      mcp { [ Host.new(settings: config) ] }
      tools { Tools.for(config) }

      Result = Struct.new(:status, :steps, :pending, :error, keyword_init: true)

      # Sent once if the model ends on a reply without handing the item off.
      # The instructions ask for this too; in live runs that alone wasn't
      # enough.
      NUDGE = "You stopped without handing the item off. End now with open_pull_request, " \
              'or update_work_item with a progress_note that starts "Blocked:" and says why.'.freeze

      # Sent when the plan turn answers in prose, so implement_model picks it up.
      CONTINUE = "Carry out your plan.".freeze

      # A chat that records its own hand-off: a pull request that went through,
      # or a Blocked note the app accepted. A denied or failed call doesn't
      # count, so the run is nudged instead of ending quietly.
      def self.chat(**)
        super.tap { |chat| track_hand_off(chat) }
      end

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

        planned = resume(chat, max_steps: [ max_steps, 1 ].min, nudge: false, **opts)
        # A plan written as prose is still a plan; implement_model carries it out.
        if planned.status == :done && !handed_off?(chat) && max_steps > 1
          chat.ask_later(CONTINUE)
          planned.status = :step_limit
        end
        # A plan that paused for approval still hands off: resume picks up
        # on implement_model.
        chat.with_model(implement_model) if %i[step_limit awaiting_approval].include?(planned.status)
        return planned unless planned.status == :step_limit && max_steps > 1

        rest = resume(chat, max_steps: max_steps - 1, **opts)
        rest.steps += planned.steps
        rest
      end

      # nudge: false leaves a reply-only ending alone (the plan turn). So does
      # a run with no steps left to answer a nudge.
      def self.resume(chat, max_steps:, nudge: true, retries: 3, sleeper: ->(s) { sleep(s) })
        steps = 0
        loop do
          if chat.complete?
            finished = handed_off?(chat) || !nudge || nudged?(chat) || steps >= max_steps
            return Result.new(status: :done, steps: steps, pending: []) if finished

            chat.ask_later(NUDGE)
          end
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

      def self.handed_off?(chat) = chat.instance_variable_get(:@feature_machine_handed_off) == true

      # Denied calls never reach after_tool_result. Thread#[] is fiber-local,
      # which keeps call and result paired when tools run concurrently.
      def self.track_hand_off(chat)
        chat.before_tool_call { |call| Thread.current[:feature_machine_call] = call }
        chat.after_tool_result do |result|
          call = Thread.current[:feature_machine_call]
          chat.instance_variable_set(:@feature_machine_handed_off, true) if call && hand_off?(call, result)
        end
      end

      def self.hand_off?(call, result)
        case call.name
        when "open_pull_request"
          result.is_a?(Hash) && !failed?(result) && result["exit_status"] == 0
        when "update_work_item"
          call.arguments.to_h.transform_keys(&:to_s)["progress_note"].to_s.start_with?("Blocked") && !failed?(result)
        else
          false
        end
      end

      # An MCP tool error, or a local tool's { "error" => ... } refusal.
      def self.failed?(result)
        return result.error? if result.respond_to?(:error?)

        result.is_a?(Hash) && (result.key?("error") || result.key?(:error))
      end

      def self.nudged?(chat)
        chat.messages.any? { |message| message.role == :user && message.content.to_s == NUDGE }
      end
      private_class_method :handed_off?, :nudged?, :track_hand_off, :hand_off?, :failed?
    end
  end
end
