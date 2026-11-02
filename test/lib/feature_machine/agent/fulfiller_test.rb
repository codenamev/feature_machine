# Plain Minitest: the loop runs against a scripted chat, no model is called.
require "minitest/autorun"
require_relative "../../../../lib/feature_machine/agent/config"
require_relative "../../../../lib/feature_machine/agent/fulfiller"

class FeatureMachine::Agent::FulfillerTest < Minitest::Test
  # Each step pops the next state: :working, :waiting, or :complete.
  Message = Struct.new(:role, :content)
  Call = Struct.new(:name, :arguments)

  class ScriptedChat
    attr_reader :staged, :steps, :models, :messages

    # handed_off: the run already handed the item off, as most do.
    def initialize(*states, handed_off: true)
      @states = states
      @state = :working
      @steps = 0
      @models = [ :plan ]
      @messages = []
      @feature_machine_handed_off = handed_off
    end

    def ask_later(text)
      @messages << Message.new(:user, text)
      @state = :working unless @staged.nil?
      (@staged ||= text) && self
    end
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

  def test_a_run_that_ends_without_a_hand_off_is_nudged_once
    chat = ScriptedChat.new(:complete, :complete, handed_off: false)
    result = Fulfiller.run(chat, item_id: 1, max_steps: 5)

    assert_equal :done, result.status
    assert_equal 2, result.steps, "one more turn after the nudge, then it stops"
    assert_equal 1, chat.messages.count { |m| m.content == Fulfiller::NUDGE }
  end

  def test_finishing_on_the_last_step_is_done_not_a_step_limit
    chat = ScriptedChat.new(:working, :complete, handed_off: false)
    result = Fulfiller.run(chat, item_id: 1, max_steps: 2)

    assert_equal :done, result.status
    assert chat.messages.none? { |m| m.content == Fulfiller::NUDGE }, "no steps left to answer a nudge"
  end

  def test_a_prose_plan_goes_to_the_implement_model_with_the_nudge_unspent
    chat = ScriptedChat.new(:complete, :complete, :complete, handed_off: false)
    result = Fulfiller.run(chat, item_id: 1, max_steps: 6, implement_model: :impl)

    assert_equal :done, result.status
    assert_equal %i[plan impl], chat.models
    assert_equal [ "Fulfil work item 1.", Fulfiller::CONTINUE, Fulfiller::NUDGE ], chat.messages.map(&:content)
  end

  # The hand-off is read from what the tools returned, through the chat's
  # own callbacks: a refused or failed call is not a hand-off.
  class CallbackChat
    def before_tool_call(&block) = @before = block
    def after_tool_result(&block) = @after = block
    def handed_off? = instance_variable_get(:@feature_machine_handed_off) == true

    def run_tool(name, arguments, result)
      @before.call(Call.new(name, arguments))
      @after.call(result)
      self
    end
  end
  McpResult = Struct.new(:error) { def error? = error }

  def tracked = CallbackChat.new.tap { |chat| Fulfiller.send(:track_hand_off, chat) }

  def test_only_a_hand_off_that_went_through_counts
    blocked = { "progress_note" => "Blocked: no criteria" }
    refute tracked.run_tool("open_pull_request", {}, { "error" => "judge rejected the change" }).handed_off?
    refute tracked.run_tool("open_pull_request", {}, { "exit_status" => 1, "output" => "no GitHub remote" }).handed_off?
    refute tracked.run_tool("update_work_item", blocked, McpResult.new(true)).handed_off?
    refute tracked.run_tool("update_work_item", { "progress_note" => "Halfway there" }, McpResult.new(false)).handed_off?
    assert tracked.run_tool("update_work_item", blocked, McpResult.new(false)).handed_off?
    assert tracked.run_tool("open_pull_request", {}, { "exit_status" => 0, "output" => "https://github.com/o/r/pull/1" }).handed_off?
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
