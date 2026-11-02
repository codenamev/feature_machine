module FeatureMachine
  # The bucketing half of triage: groups untriaged requests that are asking for
  # the same thing, ranks the groups by how many different people asked, and
  # points each group at an existing work item when one already covers it.
  #
  # Buckets are computed on demand from embeddings rather than stored, so they
  # always reflect the current inbox. Nothing here changes a record: attaching
  # a bucket to a work item is an admin's decision.
  class TriageBuckets
    # Cosine similarity at which two requests count as "the same ask", and at
    # which a bucket counts as covered by an existing work item.
    SIMILARITY_THRESHOLD = 0.55

    # Judging a bucket means judging its lead; judgments are cached per request
    # so reloading the triage page never re-asks the model the same question.
    JUDGMENT_TTL = 1.day

    Bucket = Data.define(:requests, :suggested_work_item, :suggestion_similarity, :judgment) do
      def kind = requests.first.kind
      def lead = requests.first
      def requesters_count = requests.map(&:user_id).uniq.size
      def newest_at = requests.map(&:created_at).max

      # judgment is a plain Hash of the answers (see TriageBuckets#judgment_for):
      # probabilities in 0..1, clarity a weighted level index in 0..2 (Low..High).
      def judged? = !judgment.nil?
      def bug_probability = judgment&.fetch(:bug, nil)
      def duplicate_probability = judgment&.fetch(:duplicate_of_open_item, nil)
      def clarity = judgment&.fetch(:clarity, nil)

      # The judge thinks the request was filed under the wrong kind: a bug
      # reported as a feature, or a feature asked for as a bug.
      def mis_kinded?
        return false unless bug_probability

        (kind == "bug") != (bug_probability >= 0.5)
      end
    end

    # A bucket under construction: members plus the running mean of their vectors.
    class Cluster
      attr_reader :requests, :centroid

      def initialize(request)
        @requests = [ request ]
        @vectors = [ request.embedding&.to_a ].compact
        @centroid = @vectors.first
      end

      def kind = requests.first.kind

      # Requests that haven't been embedded yet can't be compared, so each one
      # stays in a bucket of its own until its embedding lands.
      def accepts?(request)
        return false unless centroid && request.embedding && request.kind == kind

        TriageBuckets.cosine_similarity(centroid, request.embedding.to_a) >= SIMILARITY_THRESHOLD
      end

      def add(request)
        @requests << request
        @vectors << request.embedding.to_a
        @centroid = @vectors.transpose.map { |column| column.sum / column.size }
      end
    end

    def self.cosine_similarity(a, b)
      dot = norm_a = norm_b = 0.0
      a.each_with_index do |x, i|
        y = b[i]
        dot += x * y
        norm_a += x * x
        norm_b += y * y
      end
      return 0.0 if norm_a.zero? || norm_b.zero?

      dot / Math.sqrt(norm_a * norm_b)
    end

    def initialize(requests = Request.untriaged.includes(:user).oldest_first, judge: FeatureMachine.config.judge?)
      @requests = requests
      @judge = judge
    end

    # @return [Array<Bucket>] most-requested first; with a judge configured,
    #   likely bugs rank ahead of features of equal demand.
    def call
      clusters.map { |cluster| to_bucket(cluster) }
        .sort_by { |bucket| [ -bucket.requesters_count, -bucket.requests.size, -(bucket.bug_probability || 0), -bucket.newest_at.to_f ] }
    end

    private

    # Greedy single pass, oldest request first: each request joins the first
    # bucket it resembles, or starts a new one.
    def clusters
      @requests.each_with_object([]) do |request, clusters|
        cluster = clusters.find { |candidate| candidate.accepts?(request) }
        cluster ? cluster.add(request) : clusters << Cluster.new(request)
      end
    end

    def to_bucket(cluster)
      work_item, similarity = nearest_work_item(cluster)
      Bucket.new(requests: cluster.requests, suggested_work_item: work_item,
                 suggestion_similarity: similarity, judgment: judgment_for(cluster.requests.first))
    end

    # nil when judging is off or the model fails: the bucket still shows,
    # just unranked and unflagged. A missing provider key or an unknown model
    # name counts as failing; RubyLLM raises those outside RubyLLM::Error.
    def judgment_for(request)
      return nil unless @judge

      Rails.cache.fetch([ "feature_machine", "judgment", request.id, request.updated_at.to_i ], expires_in: JUDGMENT_TTL) do
        answers_hash(Judge.for(request))
      end
    rescue RubyLLM::Error, RubyLLM::ConfigurationError, RubyLLM::ModelNotFoundError => e
      Rails.logger.warn("FeatureMachine::Judge failed for request #{request.id}: #{e.message}")
      nil
    end

    # Only the numbers are kept: a RubyLLM::Judgment carries the raw provider
    # response, which has no business in the cache.
    def answers_hash(judgment)
      {
        bug: judgment.fetch(:bug).probability,
        duplicate_of_open_item: judgment.fetch(:duplicate_of_open_item).probability,
        clarity: judgment.fetch(:clarity).score
      }
    end

    def nearest_work_item(cluster)
      return [ nil, nil ] unless cluster.centroid

      nearest = WorkItem.active.embedded
        .where(kind: cluster.kind)
        .nearest_neighbors(:embedding, cluster.centroid, distance: "cosine")
        .first
      return [ nil, nil ] unless nearest

      similarity = 1.0 - nearest.neighbor_distance.to_f
      similarity >= SIMILARITY_THRESHOLD ? [ nearest, similarity ] : [ nil, nil ]
    end
  end
end
