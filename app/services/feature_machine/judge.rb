module FeatureMachine
  # The judging half of triage: a RubyLLM::Judge that reads one untriaged
  # request and answers three fixed questions about it. Nothing here changes a
  # record; the answers rank and annotate the triage list for an admin.
  #
  # Model comes from FeatureMachine.config at judge time (not at class load),
  # so a host can reconfigure it in an initializer or a test without reloading
  # this class. With config.judgment_model = nil, callers should not judge at
  # all; see TriageBuckets, which falls back to the unranked list in that case.
  class Judge < RubyLLM::Judge
    # A named provider also skips the registry lookup, so a local server's
    # own model ids resolve.
    model -> { FeatureMachine.config.judgment_model },
          provider: -> { FeatureMachine.config.judgment_provider },
          assume_model_exists: -> { !FeatureMachine.config.judgment_provider.nil? }

    probability :bug,
      "Is this request describing something broken (an error, wrong output, " \
      "a regression) rather than asking for new or changed behaviour?",
      { yes: "A crash, a wrong result, or a feature that stopped working.",
        no: "A request for a new capability or a change to behaviour that works today." }

    probability :duplicate_of_open_item,
      "Does an existing open work item already cover what this request asks for? " \
      "Compare against open_work_items.",
      { yes: "An open item already delivers the same outcome, even if it is worded differently.",
        no: "No open item delivers this outcome." }

    score :clarity,
      "How clearly does the request say what the person wants and why?",
      [ "Low", "Mid", "High" ]

    # One judgement for one request, with the open work items alongside it so
    # the duplicate question has something to compare against.
    def self.for(request, open_items: WorkItem.active.limit(50))
      judge_text(request_text(request), items_text(open_items))
    end

    # The judged input is a Hash: RubyLLM's `context:` is a configuration
    # scope, not extra prompt text, so the open items ride in the input.
    def self.judge_text(request_text, open_items_text)
      judge({ request: request_text, open_work_items: open_items_text.presence || "(none)" })
    end

    def self.request_text(request)
      [ "Kind as filed: #{request.kind}", "Title: #{request.title}", "", request.description.to_s ].join("\n")
    end

    def self.items_text(items)
      items.map { |item| "- [#{item.kind}] #{item.title}" }.join("\n")
    end
  end
end
