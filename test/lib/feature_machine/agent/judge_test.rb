# Plain Minitest: the judge's chat is scripted, no model is called.
require "minitest/autorun"
require_relative "../../../../lib/feature_machine/agent/judge"

class FeatureMachine::Agent::JudgeTest < Minitest::Test
  class ScriptedChat
    Reply = Struct.new(:content)
    attr_reader :instructions, :prompt

    def initialize(content) = @content = content
    def with_instructions(text) = (@instructions = text) && self
    def ask(text) = (@prompt = text) && Reply.new(@content)
  end

  GREEN = { "exit_status" => 0, "output" => "5 runs, 0 failures" }.freeze
  RED = { "exit_status" => 1, "output" => "1 failure" }.freeze

  def judge(reply)
    @chat = ScriptedChat.new(reply)
    @models = []
    FeatureMachine::Agent::Judge.new(model: "judge-model", chat: ->(m) { (@models << m) && @chat })
  end

  def test_red_tests_fail_without_a_model_call
    verdict = judge("unused").call(criteria: [ "x" ], diff: "+a", tests: RED)

    refute verdict.pass?
    assert_equal [ "tests failed" ], verdict.reasons
    assert_empty @models
  end

  def test_empty_diff_fails_without_a_model_call
    refute judge("unused").call(criteria: [ "x" ], diff: " \n", tests: GREEN).pass?
    assert_empty @models
  end

  def test_passes_on_a_pass_verdict
    verdict = judge(%({"pass": true, "reasons": ["meets both"]}))
              .call(criteria: [ "shows a badge", "has a test" ], diff: "+badge", tests: GREEN)

    assert verdict.pass?
    assert_equal [ "judge-model" ], @models
    assert_includes @chat.prompt, "- shows a badge\n- has a test"
    assert_includes @chat.prompt, "+badge"
    assert_includes @chat.instructions, "JSON only"
  end

  def test_reads_a_verdict_wrapped_in_prose
    verdict = judge(%(Sure.\n```json\n{"pass": false, "reasons": ["no test"]}\n```)).call(criteria: [], diff: "+a", tests: GREEN)

    refute verdict.pass?
    assert_equal [ "no test" ], verdict.reasons
  end

  def test_fails_closed_on_garbage_or_truthy_strings
    refute judge("looks good to me").call(criteria: [], diff: "+a", tests: GREEN).pass?
    refute judge(%({"pass": "true"})).call(criteria: [], diff: "+a", tests: GREEN).pass?
  end
end
