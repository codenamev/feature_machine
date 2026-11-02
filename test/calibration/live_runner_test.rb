require "minitest/autorun"
require "tmpdir"
require_relative "../../lib/feature_machine/agent/live_runner"

# LiveRunner with a scripted chat and Fulfiller: no database, no model. It
# checks the wiring (seed, scratch clone, completed-call tracking), not the
# agent.
class LiveRunnerTest < Minitest::Test
  Result = FeatureMachine::Agent::Fulfiller::Result
  Call = Struct.new(:name)

  class FakeChat
    attr_reader :approved

    def approve(call) = (@approved ||= []) << call.name
    def before_tool_call(&block) = @before = block
    def after_tool_result(&block) = @after = block

    def run_tool(name, result)
      @before.call(Call.new(name))
      @after.call(result)
    end
  end

  def setup
    @source = Dir.mktmpdir("live-runner-source")
    system("git", "init", "--quiet", @source, exception: true)
    system("git", "-C", @source, "-c", "user.name=t", "-c", "user.email=t@example.com",
           "commit", "--quiet", "--allow-empty", "-m", "init", exception: true)
    @config = FeatureMachine::Agent::Config.new(
      app_url: "http://localhost:3000", token: "t", checkout: @source,
      test_command: "true", plan_model: "plan", implement_model: "impl", max_steps: 4
    )
  end

  def teardown
    FileUtils.remove_entry(@source)
  end

  def test_runs_on_a_scratch_clone_of_the_seeded_item
    seen = {}
    runner = build(fulfil: lambda { |chat, item_id:, max_steps:, implement_model:|
      seen.merge!(item_id: item_id, max_steps: max_steps, implement_model: implement_model)
      Result.new(status: :done, steps: 1, pending: [])
    }, chat: lambda { |config|
      seen[:checkout] = config.checkout
      seen[:cloned] = File.directory?(File.join(config.checkout, ".git"))
      FakeChat.new
    })

    outcome = runner.call("title" => "x")

    assert_equal :done, outcome[:result].status
    assert_equal({ item_id: 42, max_steps: 4, implement_model: "impl" }, seen.slice(:item_id, :max_steps, :implement_model))
    refute_equal @source, seen[:checkout]
    assert seen[:cloned]
    refute File.exist?(seen[:checkout]), "scratch clone is removed after the run"
  end

  def test_completed_lists_calls_that_went_through_but_not_refusals
    runner = build(fulfil: lambda { |chat, **|
      chat.run_tool("read_file", "contents")
      chat.run_tool("open_pull_request", { "error" => "refusing to open a pull request from main" })
      chat.run_tool("run_tests", { "passed" => true })
      Result.new(status: :done, steps: 1, pending: [])
    })

    assert_equal %w[read_file run_tests], runner.call({})[:completed]
  end

  def test_progress_notes_are_approved_and_the_pull_request_is_held
    resumes = []
    chat = FakeChat.new
    runner = build(
      chat: ->(_) { chat },
      fulfil: ->(*, **) { Result.new(status: :awaiting_approval, steps: 1, pending: [ Call.new("update_work_item") ]) },
      resume: lambda { |_chat, max_steps:|
        resumes << max_steps
        Result.new(status: :awaiting_approval, steps: 2, pending: [ Call.new("update_work_item"), Call.new("open_pull_request") ])
      }
    )

    result = runner.call({})[:result]

    assert_equal [ 3 ], resumes, "resumes with what's left of max_steps"
    assert_equal %w[update_work_item update_work_item], chat.approved
    assert_equal :awaiting_approval, result.status
    assert_equal %w[open_pull_request], result.pending.map(&:name)
    assert_equal 3, result.steps
  end

  def test_an_uncloneable_checkout_raises
    @config.instance_variable_set(:@checkout, File.join(@source, "missing"))

    assert_raises(ArgumentError) { build.call({}) }
  end

  private

  def build(fulfil: ->(*, **) { Result.new(status: :done, steps: 0, pending: []) }, chat: ->(_) { FakeChat.new },
            resume: ->(*, **) { flunk "resumed without a routine approval" })
    FeatureMachine::Agent::LiveRunner.new(config: @config, seed: ->(_) { 42 }, fulfil: fulfil, resume: resume, chat: chat)
  end
end
