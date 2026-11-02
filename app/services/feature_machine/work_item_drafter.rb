module FeatureMachine
  # Turns a bucket of user requests into a draft specification for a work item.
  #
  # The output is always a draft for an admin to edit and approve: the requests
  # are user-written text and are handed to the model as quoted data, never as
  # instructions. The model call goes through Drafter, a RubyLLM::Agent that
  # carries the system prompt and the output schema. When the model is
  # unavailable, or the host configured none (config.drafter_model = nil), the
  # draft falls back to a plain digest of the requests, so forming a work item
  # never depends on the network.
  class WorkItemDrafter
    FIELDS = %w[title summary problem scope acceptance_criteria].freeze

    Draft = Data.define(:attributes, :source) do
      def from_model? = source == :model
    end

    def initialize(requests, kind: nil)
      @requests = requests.to_a
      @kind = (kind || @requests.first&.kind || "feature").to_s
    end

    # @return [Draft] attributes for a WorkItem, and whether the model wrote them
    def call
      model_draft || fallback_draft
    end

    private

    def model_draft
      return nil if @requests.empty? || !config.drafter?

      content = Drafter.chat.ask(prompt).content
      # Structured output arrives as a Hash or as its JSON text, depending on
      # the provider path; anything else raises here and falls back.
      content = JSON.parse(content) if content.is_a?(String)
      return nil unless content.is_a?(Hash)

      attributes = content.slice(*FIELDS).transform_values { |value| value.to_s.strip }
      return nil if attributes["title"].blank?

      Draft.new(attributes: clamp(attributes), source: :model)
    rescue StandardError => e
      Rails.logger.error "WorkItemDrafter failed, using fallback draft: #{e.class}: #{e.message}"
      nil
    end

    def config
      FeatureMachine.config
    end

    def prompt
      requesters = @requests.map(&:user_id).uniq.size
      <<~PROMPT
        Kind of work: #{@kind}
        #{@requests.size} request(s) from #{requesters} distinct user(s):

        #{@requests.map { |request| quoted(request) }.join("\n\n")}
      PROMPT
    end

    def quoted(request)
      <<~REQUEST.strip
        <request id="#{request.id}" filed="#{request.created_at.to_date}">
        Title: #{request.title}
        #{request.description}
        </request>
      REQUEST
    end

    def fallback_draft
      lead = @requests.first
      attributes = {
        "title" => lead&.title || "Untitled work item",
        "problem" => @requests.map { |request|
          [ "- #{FeatureMachine.config.label_for(request.user)}: #{request.title}", request.description.presence ].compact.join(" - ")
        }.join("\n")
      }
      Draft.new(attributes: clamp(attributes), source: :fallback)
    end

    # Keep model output inside the model's validations rather than failing the save.
    def clamp(attributes)
      attributes.merge(
        "title" => attributes["title"].to_s.truncate(120),
        "summary" => attributes["summary"].to_s.truncate(600).presence,
        "problem" => attributes["problem"].to_s.truncate(5000).presence
      ).compact
    end
  end
end
