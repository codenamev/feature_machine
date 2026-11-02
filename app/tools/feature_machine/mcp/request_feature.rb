module FeatureMachine
  module Mcp
    class RequestFeature < Base
      tool_name "request_feature"
      description "File a feature request on the user's behalf. Only the user and the maintainers see it; " \
                  "it starts as `requested` and list_feature_requests shows where it stands. " \
                  "Something broken is a bug report, not a feature request: use report_bug. " \
                  "Call list_feature_requests first: if the user already asked for this, tell them " \
                  "instead of filing a duplicate. Describe the problem the user has, not the implementation."
      input_schema(
        properties: {
          title:       { type: "string", description: "One line, 8-120 characters, the way the user would say it." },
          description: { type: "string", description: "What the user is trying to do and what gets in the way today. Up to 2000 characters." }
        },
        required: [ "title" ]
      )
      annotations(destructive_hint: false)

      def self.call(title:, description: nil, server_context: nil)
        with_user(server_context, scope: ::FeatureMachine::WRITE) do |user, _credential|
          request = ::FeatureMachine::Request.owned_by(user).feature.create!(title: title, description: description)
          ok(feature_request_payload(request))
        end
      end
    end
  end
end
