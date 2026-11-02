module FeatureMachine
  module Mcp
    class ListFeatureRequests < Base
      tool_name "list_feature_requests"
      description "The user's own feature requests, newest first, each with its status " \
                  "(requested, planned, in_progress, shipped, declined) and the maintainer's progress note. " \
                  "Call it before filing a request so you don't file a duplicate, and to tell the user where " \
                  "something they asked for stands. Other people's requests are never listed; read_roadmap shows " \
                  "what is planned for everyone."
      input_schema(
        properties: {
          status: { type: "string", enum: ::FeatureMachine::Request.statuses.keys, description: "Only requests in this status." }
        },
        required: []
      )
      annotations(read_only_hint: true)

      def self.call(status: nil, server_context: nil)
        with_user(server_context, scope: ::FeatureMachine::READ) do |user, _credential|
          next error("Unknown status #{status.inspect}. One of: #{::FeatureMachine::Request.statuses.keys.join(', ')}.") if status && !::FeatureMachine::Request.statuses.key?(status)

          requests = ::FeatureMachine::Request.owned_by(user).feature.includes(:work_item).newest_first
          requests = requests.where(status: status) if status
          ok(requests: requests.map { |request| feature_request_payload(request) })
        end
      end
    end
  end
end
