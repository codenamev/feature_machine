# Plain Minitest: the loop runs against a scripted chat, no model is called.
require "minitest/autorun"
require_relative "../../../../lib/feature_machine/agent/config"
require_relative "../../../../lib/feature_machine/agent/fulfiller"

class FeatureMachine::Agent::FulfillerTest < Minitest::Test
  # Each step pops the next state: :working, :waiting, or :complete.
  class ScriptedChat
    attr_reader :staged, :steps, :models

    def initialize(*states)
      @states = states
      @state = :working
      @steps = 0
      @models = [ :plan ]
    end

    def ask_later(text) = (@staged = text) && self
    def with_model(model) = (@models << model) && self
    def step
      @steps += 1
      @models_by_step = (@models_by_step || []) << @models.last
      next_state = @states.shift || :working
      raise next_state if next_state.is_a?(Exception)
      @state = next_state
    end
    def complete? = @state == :complete
    def waiting? = @state == :waiting
    def pending_approvals = waiting? ? [ :update_work_item ] : []
    def approve(_call) = @state = :working
    def models_by_step = @models_by_step || []
  end

  Fulfiller = FeatureMachine::Agent::Fulfiller

  def test_stages_the_item_and_runs_to_done
    chat = ScriptedChat.new(:working, :complete)
    result = Fulfiller.run(chat, item_id: 42, max_steps: 5)

    assert_equal "Fulfil work item 42.", chat.staged
    assert_equal :done, result.status
    assert_equal 2, result.steps
  end

  def test_pauses_for_approval
    result = Fulfiller.run(ScriptedChat.new(:waiting), item_id: 1, max_steps: 5)

    assert_equal :awaiting_approval, result.status
    assert_equal [ :update_work_item ], result.pending
  end

  def test_stops_at_the_step_limit
    chat = ScriptedChat.new
    result = Fulfiller.run(chat, item_id: 1, max_steps: 3)

    assert_equal :step_limit, result.status
    assert_equal 3, chat.steps
  end

  def test_resume_continues_after_a_decision
    chat = ScriptedChat.new(:waiting, :complete)
    assert_equal :awaiting_approval, Fulfiller.run(chat, item_id: 1, max_steps: 5).status
    chat.approve(chat.pending_approvals.first)
    assert_equal :done, Fulfiller.resume(chat, max_steps: 5).status
  end

  def test_retries_transient_errors_with_backoff
    naps = []
    chat = ScriptedChat.new(RubyLLM::RateLimitError.new("429"), RubyLLM::OverloadedError.new("529"), :complete)
    result = Fulfiller.run(chat, item_id: 1, max_steps: 1, sleeper: naps.method(:<<))

    assert_equal :done, result.status
    assert_equal [ 2, 4 ], naps
    assert_equal 1, result.steps, "retried attempts don't spend steps"
  end

  def test_fails_once_retries_run_out
    errors = Array.new(3) { RubyLLM::ServerError.new("500") }
    result = Fulfiller.run(ScriptedChat.new(*errors), item_id: 1, max_steps: 5, retries: 2, sleeper: ->(_) { })

    assert_equal :failed, result.status
    assert_kind_of RubyLLM::ServerError, result.error
  end

  def test_fails_fast_on_permanent_errors
    naps = []
    result = Fulfiller.run(ScriptedChat.new(RubyLLM::UnauthorizedError.new("401")), item_id: 1, max_steps: 5, sleeper: naps.method(:<<))

    assert_equal :failed, result.status
    assert_kind_of RubyLLM::UnauthorizedError, result.error
    assert_empty naps
  end

  def test_plans_on_one_model_then_implements_on_another
    chat = ScriptedChat.new(:working, :working, :complete)
    result = Fulfiller.run(chat, item_id: 1, max_steps: 5, implement_model: :impl)

    assert_equal :done, result.status
    assert_equal 3, result.steps
    assert_equal %i[plan impl impl], chat.models_by_step
  end

  def test_switches_models_even_when_the_plan_pauses_for_approval
    chat = ScriptedChat.new(:waiting, :complete)
    assert_equal :awaiting_approval, Fulfiller.run(chat, item_id: 1, max_steps: 5, implement_model: :impl).status
    chat.approve(chat.pending_approvals.first)
    Fulfiller.resume(chat, max_steps: 5)

    assert_equal %i[plan impl], chat.models_by_step
  end

  def test_no_switch_when_the_plan_finishes_the_item
    chat = ScriptedChat.new(:complete)
    Fulfiller.run(chat, item_id: 1, max_steps: 5, implement_model: :impl)

    assert_equal [ :plan ], chat.models
  end

  def test_declares_model_and_host_mcp
    assert_operator Fulfiller, :<, RubyLLM::Agent
    assert_kind_of Proc, Fulfiller.mcp, "host is built per chat from config"
  end
end
