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
    model { FeatureMachine.config.judgment_model }

    probability :bug,
      "Is this request describing something broken (an error, wrong output, " \
      "a regression) rather than asking for new or changed behaviour?",
      "Reports of crashes, wrong results, or features that stopped working are bugs. " \
      "Requests for new capabilities or changes to working behaviour are not."

    probability :duplicate_of_open_item,
      "Does an existing open work item already cover what this request asks for?",
      "Compare against the open work items in the context. Same outcome asked " \
      "in different words still counts as a duplicate."

    score :clarity,
      "How clearly does the request say what the person wants and why?",
      [ "Low", "Mid", "High" ]

    # One judgement for one request, with the open work items as context so the
    # duplicate question has something to compare against.
    def self.for(request, open_items: WorkItem.active.limit(50))
      judge(request_text(request), context: items_text(open_items))
    end

    def self.request_text(request)
      [ "Kind as filed: #{request.kind}", "Title: #{request.title}", "", request.description.to_s ].join("\n")
    end

    def self.items_text(items)
      items.map { |item| "- [#{item.kind}] #{item.title}" }.join("\n")
    end
  end
end
