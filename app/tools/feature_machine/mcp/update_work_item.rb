module FeatureMachine
  module Mcp
    class UpdateWorkItem < Base
      tool_name "update_work_item"
      description "Maintainer only. Pick up a work item, hand it back for review, and report progress. " \
                  "`in_progress` picks up a planned item (fails if someone already has). When the work is in a " \
                  "pull request, set `in_review` with `pull_request_url`: that is how the maintainer learns it is " \
                  "waiting on them. `in_progress` again takes it back after review feedback, `shipped` marks it live, " \
                  "`planned` puts it back in the queue. To report progress without changing status, send only " \
                  "`progress_note`: it is shown to users on the roadmap and on their own requests, so write it for " \
                  "them. You cannot edit the spec, approve drafts, or decline work: those are the maintainer's."
      input_schema(
        properties: {
          id:               { type: "integer", description: "The work item id." },
          status:           { type: "string", enum: ::FeatureMachine::WorkItem::MAINTAINER_STATUSES, description: "The status to move to." },
          pull_request_url: { type: "string", description: "The GitHub pull request implementing this item, e.g. https://github.com/owner/repo/pull/123. Required for in_review." },
          progress_note:    { type: "string", description: "User-facing note on where this stands. Up to 1000 characters." }
        },
        required: [ "id" ]
      )
      annotations(destructive_hint: false)

      def self.call(id:, status: nil, pull_request_url: nil, progress_note: nil, server_context: nil)
        with_user(server_context, scope: ::FeatureMachine::MAINTAINER) do |_user, _credential|
          work_item = ::FeatureMachine::WorkItem.where(status: ListWorkItems::STATUSES).find(id)
          changes = { progress_note: progress_note, pull_request_url: pull_request_url }.compact
          status ? work_item.agent_transition!(status, changes) : work_item.update!(changes)
          ok(work_item_payload(work_item))
        end
      end
    end
  end
end
