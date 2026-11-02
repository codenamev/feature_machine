require "yaml"

module FeatureMachine
  # Runs the mutation calibration cases (calibration/judge_cases.yml)
  # through a judge and says which ones it got wrong. Three checks per case:
  #
  #   base        lands on base.expect
  #   equivalent  stays within the drift threshold of the base answer
  #   faulty      lands on faulty.expect
  #
  # The judge is anything that answers `call(text, context)` with a hash-like
  # judgment (`fetch(question)` returning an answer with #probability or
  # #score). The default calls FeatureMachine::Judge against the configured
  # judgment_model, so `rake feature_machine:calibrate_judge` costs real tokens.
  # Tests pass a fake.
  class JudgeCalibration
    CASES_PATH = File.expand_path("calibration/judge_cases.yml", __dir__)
    SCORE_LEVELS = %w[Low Mid High].freeze
    Request = Struct.new(:kind, :title, :description, keyword_init: true)
    Check = Struct.new(:case_id, :variant, :ok, :detail, keyword_init: true)

    def self.load(path = CASES_PATH)
      new(YAML.safe_load_file(path))
    end

    def initialize(file, judge: nil)
      @file = file
      @judge = judge || ->(text, open_items) { Judge.judge_text(text, open_items) }
    end

    def run
      @file.fetch("cases").flat_map { |c| check(c) }
    end

    private

    def check(c)
      question = c.fetch("question").to_sym
      base = answer(c["base"], question)
      equivalent = answer(c["equivalent"], question)
      faulty = answer(c["faulty"], question)

      [
        Check.new(case_id: c["id"], variant: "base", ok: label(base, question) == c["base"]["expect"],
                  detail: "#{format(base)} (want #{c["base"]["expect"]})"),
        Check.new(case_id: c["id"], variant: "equivalent", ok: (base - equivalent).abs <= max_drift(question),
                  detail: "#{format(equivalent)} vs base #{format(base)} (max drift #{max_drift(question)})"),
        Check.new(case_id: c["id"], variant: "faulty", ok: label(faulty, question) == c["faulty"]["expect"],
                  detail: "#{format(faulty)} (want #{c["faulty"]["expect"]})")
      ]
    end

    # A probability as a Float, or a score as a level index (Integer).
    def answer(variant, question)
      request = Request.new(kind: variant["kind"], title: variant["title"], description: variant["description"])
      result = @judge.call(Judge.request_text(request), context).fetch(question)
      score_question?(question) ? result.score.round : result.probability
    end

    def label(value, question)
      return SCORE_LEVELS.fetch(value) if score_question?(question)

      value >= 0.5 ? "high" : "low"
    end

    def max_drift(question)
      key = score_question?(question) ? "score_drift" : "probability_drift"
      @file.fetch("thresholds").fetch(key)
    end

    def score_question?(question) = question == :clarity

    def format(value) = value.is_a?(Integer) ? SCORE_LEVELS.fetch(value) : value.round(2).to_s

    def context
      @context ||= Judge.items_text(@file.fetch("open_items").map { |title| title_item(title) })
    end

    # "[feature] Pin articles..." back into the kind/title shape items_text reads.
    def title_item(line)
      kind, title = line.match(/\A\[(\w+)\] (.+)\z/).captures
      Request.new(kind: kind, title: title)
    end
  end
end
