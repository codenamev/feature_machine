module FeatureMachine::WorkItemsHelper
  WORK_ITEM_STATUS_TONES = {
    "draft" => :neutral,
    "planned" => :info,
    "in_progress" => :progress,
    "in_review" => :info,
    "shipped" => :success,
    "declined" => :danger
  }.freeze

  WORK_ITEM_STATUS_LABELS = {
    "draft" => "Draft",
    "planned" => "Planned",
    "in_progress" => "In progress",
    "in_review" => "In review",
    "shipped" => "Shipped",
    "declined" => "Declined"
  }.freeze

  WORK_ITEM_STATUS_BLURBS = {
    "draft" => "Formed from requests, not yet a commitment. Private until planned.",
    "in_review" => "Built, with a pull request waiting on you. Users still see these as in progress.",
    "in_progress" => "Being built right now.",
    "planned" => "Accepted and queued. Order here isn't a promise about order of delivery.",
    "shipped" => "Live on %{product}.",
    "declined" => "Not going to happen."
  }.freeze

  def work_item_status_label(status)
    WORK_ITEM_STATUS_LABELS.fetch(status.to_s)
  end

  # The shipped line names the host's product, so it is built at call time
  # from FeatureMachine.config rather than frozen here.
  def work_item_status_blurb(status)
    format(WORK_ITEM_STATUS_BLURBS.fetch(status.to_s), product: FeatureMachine.config.product_name)
  end

  # The status chip. Admin pages show the real status; anything users see
  # passes `public: true`, which folds review into "In progress".
  def work_item_status(work_item, public: false)
    status = public ? work_item.public_status : work_item.status
    work_item_status_chip(tone: WORK_ITEM_STATUS_TONES.fetch(status), pulse: status == "in_progress") do
      work_item_status_label(status)
    end
  end

  # Engine-local status chip. Emits the same class hooks the host's design
  # system styles (cn-nr-status*), so the engine owns no CSS and no component
  # dependency; a host without those hooks still gets a sane unstyled chip.
  def work_item_status_chip(tone: :neutral, pulse: false, &block)
    classes = [
      "cn-nr-status inline-flex items-center gap-1 whitespace-nowrap rounded-full px-2 py-0.5 text-xs font-semibold",
      "cn-nr-status-tone-#{tone}"
    ].join(" ")
    data = { slot: "nr-status", tone: tone }
    data[:pulse] = "true" if pulse
    content_tag(:span, class: classes, data: data) do
      safe_join([
        content_tag(:span, "", class: "cn-nr-status-dot size-1.5 shrink-0 rounded-full bg-current",
                                data: { slot: "nr-status-dot" }, aria: { hidden: true }),
        capture(&block)
      ], " ")
    end
  end

  # "Feature" / "Bug", or "Fix" once a bug has shipped: the changelog reads
  # as what changed, not what was wrong.
  def work_kind_label(record)
    return "Fix" if record.bug? && record.try(:shipped?)

    record.bug? ? "Bug" : "Feature"
  end

  # How much demand sits behind a work item, counting people rather than requests.
  def work_item_demand(work_item)
    people = work_item.feature_requests.map(&:user_id).uniq.size
    people.zero? ? nil : "#{pluralize(people, 'person')} asked"
  end

  # The pull request's address, rebuilt from the fixed GitHub origin and the
  # validated path. Nil when there is no usable pull request.
  def pull_request_href(work_item)
    path = work_item.pull_request_path
    "#{::FeatureMachine::WorkItem::GITHUB}#{path}" if path
  end

  # A new item may start anywhere; a saved one offers where it stands plus
  # the moves its transition table allows.
  def work_item_status_options(work_item = nil)
    statuses = ::FeatureMachine::WorkItem.statuses.keys
    statuses &= [ work_item.status_in_database, *work_item.next_statuses ] if work_item&.persisted?
    statuses.map { |status| [ work_item_status_label(status), status ] }
  end

  def work_item_relation_options
    ::FeatureMachine::WorkItemRelation::KINDS.map { |kind, (forward, _inverse)| [ forward, kind ] }
  end
end
