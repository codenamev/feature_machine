# Plain Minitest, like config_test: the CLI must boot without Rails.
require "minitest/autorun"
require "stringio"
require "tmpdir"
require_relative "../../../../lib/feature_machine/agent"

class FeatureMachine::Agent::CLITest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    Dir.mkdir(File.join(@dir, ".git"))
    @env = { "FEATURE_MACHINE_TOKEN" => "tok", "FEATURE_MACHINE_APP_URL" => "https://example.test" }
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  Result = Struct.new(:status, :steps, :pending, :error, keyword_init: true)
  Call = Struct.new(:name, :arguments)

  # Stands in for Fulfiller: pauses for approval on each call in `pauses`,
  # then finishes with `final`, recording what the CLI decided.
  class FakeFulfiller
    attr_reader :decisions, :budgets

    def initialize(pauses:, final:)
      @pauses = pauses
      @final = final
      @decisions = []
      @budgets = []
    end

    def chat(config:) = self
    def approve(call) = @decisions << [ call.name, :approved ]
    def deny(call) = @decisions << [ call.name, :denied ]

    def run(_chat, item_id:, max_steps:, implement_model:)
      @budgets << max_steps
      next_result
    end

    def resume(_chat, max_steps:)
      @budgets << max_steps
      next_result
    end

    private

    def next_result
      call = @pauses.shift
      call ? Result.new(status: :awaiting_approval, steps: 2, pending: [ call ]) : @final
    end
  end

  def run_cli(*argv, env: @env, input: "", queue: ->(_config) { [] }, fulfiller: nil)
    out = StringIO.new
    err = StringIO.new
    status = FeatureMachine::Agent::CLI.start(argv, out: out, err: err, env: env, input: StringIO.new(input),
                                                    queue: queue, fulfiller: fulfiller)
    [ status, out.string, err.string ]
  end

  def test_agent_loads_config_and_reports_it
    status, out, = run_cli("agent", "--checkout", @dir, "--max-steps", "5")
    assert_equal 0, status
    assert_includes out, "https://example.test -> #{@dir}"
    assert_includes out, "max_steps: 5"
  end

  def test_without_a_work_item_it_lists_the_planned_queue
    queue = ->(_config) { [ { "id" => 7, "title" => "Dark mode for everyone" } ] }
    status, out, = run_cli("agent", "--checkout", @dir, queue: queue)
    assert_equal 0, status
    assert_includes out, "#7  Dark mode for everyone"
    assert_includes out, "--work-item ID"
  end

  def test_a_queue_that_cannot_be_read_fails_with_the_reason
    status, _, err = run_cli("agent", "--checkout", @dir, queue: ->(_config) { raise "Invalid params" })
    assert_equal 1, status
    assert_includes err, "could not list work items from https://example.test: Invalid params"
  end

  def test_working_an_item_needs_a_plan_model
    status, _, err = run_cli("agent", "--checkout", @dir, "--work-item", "7")
    assert_equal 64, status
    assert_includes err, "--plan-model is required"
  end

  def test_every_approval_is_asked_and_the_answer_is_honoured
    fulfiller = FakeFulfiller.new(pauses: [ Call.new("update_work_item", { "id" => 7 }), Call.new("open_pull_request", { "title" => "x" }) ],
                                  final: Result.new(status: :done, steps: 1, pending: []))
    status, out, = run_cli("agent", "--checkout", @dir, "--work-item", "7", "--plan-model", "m", "--max-steps", "10",
                           input: "y\nn\n", fulfiller: fulfiller)

    assert_equal 0, status
    assert_equal [ [ "update_work_item", :approved ], [ "open_pull_request", :denied ] ], fulfiller.decisions
    assert_equal [ 10, 8, 6 ], fulfiller.budgets, "approvals don't spend steps, but steps carry across resumes"
    assert_includes out, "The agent wants to call open_pull_request"
    assert_includes out, "Done in 5 steps."
  end

  def test_no_answer_is_a_denial
    fulfiller = FakeFulfiller.new(pauses: [ Call.new("update_work_item", {}) ], final: Result.new(status: :done, steps: 0, pending: []))
    run_cli("agent", "--checkout", @dir, "--work-item", "7", "--plan-model", "m", input: "", fulfiller: fulfiller)
    assert_equal [ [ "update_work_item", :denied ] ], fulfiller.decisions
  end

  def test_a_run_that_stops_short_exits_nonzero
    fulfiller = FakeFulfiller.new(pauses: [], final: Result.new(status: :step_limit, steps: 3, pending: []))
    status, _, err = run_cli("agent", "--checkout", @dir, "--work-item", "7", "--plan-model", "m", fulfiller: fulfiller)
    assert_equal 1, status
    assert_includes err, "Stopped at max_steps"
  end

  def test_an_unreachable_app_fails_with_a_message_not_a_trace
    require "ruby_llm"
    fulfiller = FakeFulfiller.new(pauses: [], final: nil)
    fulfiller.define_singleton_method(:chat) { |config:| raise RubyLLM::MCP::Error, "Failed to open TCP connection to example.test:443" }
    status, _, err = run_cli("agent", "--checkout", @dir, "--work-item", "7", "--plan-model", "m", fulfiller: fulfiller)

    assert_equal 1, status
    assert_includes err, "Could not work with https://example.test/mcp: Failed to open TCP connection"
  end

  def test_a_refused_connection_fails_with_a_message_not_a_trace
    require "ruby_llm"
    fulfiller = FakeFulfiller.new(pauses: [], final: nil)
    fulfiller.define_singleton_method(:chat) { |config:| raise Faraday::ConnectionFailed, "Failed to open TCP connection to example.test:443" }
    status, _, err = run_cli("agent", "--checkout", @dir, "--work-item", "7", "--plan-model", "m", fulfiller: fulfiller)

    assert_equal 1, status
    assert_includes err, "Network error: Failed to open TCP connection to example.test:443"
  end

  def test_agent_help_prints_usage
    status, out, = run_cli("agent", "--help")
    assert_equal 0, status
    assert_includes out, "With --work-item ID"
  end

  def test_provider_keys_come_from_their_conventional_variables
    require "ruby_llm"
    saved = RubyLLM.config.openai_api_key
    RubyLLM.config.openai_api_key = nil
    FeatureMachine::Agent.configure_providers({ "OPENAI_API_KEY" => "sk-test" })
    assert_equal "sk-test", RubyLLM.config.openai_api_key
  ensure
    RubyLLM.config.openai_api_key = saved
  end

  def test_missing_token_is_a_usage_error
    status, _, err = run_cli("agent", "--checkout", @dir, env: { "FEATURE_MACHINE_APP_URL" => "https://example.test" })
    assert_equal 64, status
    assert_includes err, "FEATURE_MACHINE_TOKEN"
  end

  def test_token_flag_is_not_accepted
    status, _, err = run_cli("agent", "--checkout", @dir, "--token", "x")
    assert_equal 64, status
    assert_includes err, "--token"
  end

  def test_unknown_command
    status, _, err = run_cli("deploy")
    assert_equal 64, status
    assert_includes err, "unknown command: deploy"
  end

  def test_help
    status, out, = run_cli("--help")
    assert_equal 0, status
    assert_includes out, "usage: feature_machine agent"
  end
end
