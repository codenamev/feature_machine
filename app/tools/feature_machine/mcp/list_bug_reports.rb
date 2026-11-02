module FeatureMachine
  module Mcp
    class ListBugReports < Base
      tool_name "list_bug_reports"
      description "The user's own bug reports, newest first, each with its status " \
                  "(requested = reported, planned = confirmed, in_progress = being fixed, shipped = fixed, " \
                  "declined = won't fix) and the maintainer's progress note. Use it to tell the user whether " \
                  "something they reported has been fixed. Other people's reports are never listed."
      input_schema(properties: {}, required: [])
      annotations(read_only_hint: true)

      def self.call(server_context: nil)
        with_user(server_context, scope: ::FeatureMachine::READ) do |user, _credential|
          reports = ::FeatureMachine::Request.owned_by(user).bug.includes(:work_item).newest_first
          ok(bug_reports: reports.map { |report| feature_request_payload(report) })
        end
      end
    end
  end
end
