module FeatureMachine::FeatureRequestsHelper
  # Status -> the design system's status tone. One place, so the board, the
  # summary strip and any future email all agree on what "planned" looks like.
  STATUS_TONES = {
    "requested" => :neutral,
    "planned" => :info,
    "in_progress" => :progress,
    "shipped" => :success,
    "declined" => :danger
  }.freeze

  STATUS_LABELS = {
    "requested" => "Requested",
    "planned" => "Planned",
    "in_progress" => "In progress",
    "shipped" => "Shipped",
    "declined" => "Declined"
  }.freeze

  # A bug isn't "requested" or "shipped"; same lifecycle, said the way the
  # reporter would.
  BUG_STATUS_LABELS = STATUS_LABELS.merge(
    "requested" => "Reported",
    "planned" => "Confirmed",
    "in_progress" => "Being fixed",
    "shipped" => "Fixed",
    "declined" => "Won't fix"
  ).freeze

  # What each status means for the person who reported the bug.
  BUG_STATUS_BLURBS = {
    "requested" => "We have your report and haven't looked at it yet.",
    "planned" => "Confirmed and queued for a fix.",
    "in_progress" => "A fix is being worked on now.",
    "shipped" => "The fix is live.",
    "declined" => "We're not going to change this."
  }.freeze

  # What each status means for the person who asked for the feature. The
  # shipped line names the host's product, so it is built at call time from
  # FeatureMachine.config rather than frozen here.
  STATUS_BLURBS = {
    "requested" => "We have your request and haven't decided on it yet.",
    "planned" => "Accepted and queued. It's on the roadmap.",
    "in_progress" => "Being built right now.",
    "shipped" => "Live on %{product}.",
    "declined" => "We're not going to build this."
  }.freeze

  # The one-line explanation of where a request stands, worded by kind.
  def request_status_blurb(feature_request)
    blurbs = feature_request.bug? ? BUG_STATUS_BLURBS : STATUS_BLURBS
    format(blurbs.fetch(feature_request.status), product: FeatureMachine.config.product_name)
  end

  # The status chip for a request: tone from the status, pulse while in
  # progress, wording by kind.
  def feature_request_status(feature_request)
    status = feature_request.status
    labels = feature_request.bug? ? BUG_STATUS_LABELS : STATUS_LABELS
    feature_machine_status(tone: STATUS_TONES.fetch(status), pulse: feature_request.in_progress?) do
      labels.fetch(status)
    end
  end

  # Engine-local status chip. Emits the same class hooks the host's design
  # system styles (cn-nr-status*), so the engine owns no CSS and no component
  # dependency; a host without those hooks still gets a sane unstyled chip.
  def feature_machine_status(tone: :neutral, pulse: false, &block)
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

  # A host link the engine offers only when the host configured it.
  def feature_machine_host_link(name, text, **options)
    path = FeatureMachine.config.host_path(name, self)
    link_to(text, path, **options) if path
  end
end
