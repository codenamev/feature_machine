module FeatureMachine
  module Mcp
    class GetWorkItem < Base
      tool_name "get_work_item"
      description "Maintainer only. One approved work item with its full specification (problem, scope, acceptance " \
                  "criteria), related work, and the user requests behind it. Re-read it before changing its status."
      input_schema(
        properties: { id: { type: "integer", description: "The work item id." } },
        required: [ "id" ]
      )
      annotations(read_only_hint: true)

      def self.call(id:, server_context: nil)
        with_user(server_context, scope: ::FeatureMachine::MAINTAINER) do |_user, _credential|
          ok(work_item_payload(::FeatureMachine::WorkItem.where(status: ListWorkItems::STATUSES).find(id)))
        end
      end
    end
  end
end
