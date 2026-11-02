module FeatureMachine
  module Mcp
    class ReportBug < Base
      tool_name "report_bug"
      description "Report a bug on the user's behalf. Only the user and the maintainers see it; " \
                  "list_bug_reports shows where it stands and the fix appears in read_roadmap. Say what the " \
                  "user did, what they expected, and what happened instead. For something missing rather than " \
                  "broken, use request_feature."
      input_schema(
        properties: {
          title:       { type: "string", description: "One line, 8-120 characters, naming what went wrong." },
          description: { type: "string", description: "What the user did, what they expected, and what happened instead. Up to 2000 characters." }
        },
        required: [ "title" ]
      )
      annotations(destructive_hint: false)

      def self.call(title:, description: nil, server_context: nil)
        with_user(server_context, scope: ::FeatureMachine::WRITE) do |user, _credential|
          report = ::FeatureMachine::Request.owned_by(user).bug.create!(title: title, description: description)
          ok(feature_request_payload(report))
        end
      end
    end
  end
end
