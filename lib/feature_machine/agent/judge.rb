require "json"
require "ruby_llm"

module FeatureMachine
  module Agent
    # The submit gate. Before the Fulfiller may open a PR, a separate chat
    # reads the diff and the test run against the item's acceptance criteria.
    # Red tests never reach the model: that verdict costs nothing.
    class Judge
      Verdict = Struct.new(:pass, :reasons, keyword_init: true) do
        def pass? = pass
      end

      INSTRUCTIONS = <<~TEXT.freeze
        You review a change before it is submitted. Given acceptance
        criteria, a diff, and a passing test run, decide whether the diff
        meets every criterion. Unmet, untested, or out-of-scope changes fail.
        Reply with JSON only: {"pass": true|false, "reasons": ["..."]}.
      TEXT

      def initialize(model:, chat: ->(m) { RubyLLM.chat(model: m) })
        @model = model
        @chat = chat
      end

      # tests is the RunTests result: {"exit_status" => Integer, "output" => String}.
      def call(criteria:, diff:, tests:)
        return Verdict.new(pass: false, reasons: [ "tests failed" ]) unless tests["exit_status"] == 0
        return Verdict.new(pass: false, reasons: [ "empty diff" ]) if diff.to_s.strip.empty?

        reply = @chat.call(@model).with_instructions(INSTRUCTIONS).ask(prompt(criteria, diff, tests))
        parse(reply.content)
      end

      private

      def prompt(criteria, diff, tests)
        <<~TEXT
          ## Acceptance criteria
          #{Array(criteria).map { |c| "- #{c}" }.join("\n")}

          ## Diff
          #{diff}

          ## Test run (passed)
          #{tests["output"].to_s.lines.last(20).join}
        TEXT
      end

      # Anything but a well-formed verdict fails closed.
      def parse(content)
        json = JSON.parse(content.to_s[/\{.*\}/m] || "")
        Verdict.new(pass: json["pass"] == true, reasons: Array(json["reasons"]).map(&:to_s))
      rescue JSON::ParserError
        Verdict.new(pass: false, reasons: [ "judge reply was not a verdict" ])
      end
    end
  end
end
