module FeatureMachine
  module Mcp
    class Base < ::MCP::Tool
      class << self
        private

        # Every tool goes through here: resolves the credential from
        # server_context, checks the scope, and translates the model layer's
        # exceptions into agent-legible tool errors.
        def with_user(server_context, scope:)
          credential = server_context && server_context[:credential]
          return error("Not authenticated. Connect with `Authorization: Bearer <token>`.#{token_hint}") unless credential&.user
          return error("This token lacks the `#{scope}` scope.#{token_hint}") unless ::FeatureMachine::Auth.allows?(credential, scope)

          yield credential.user, credential
        rescue ActiveRecord::RecordNotFound
          error("Not found. Verify the id belongs to the authenticated user.")
        rescue ActiveRecord::RecordInvalid => e
          error("Validation failed: #{e.record.errors.full_messages.to_sentence}")
        rescue ::FeatureMachine::WorkItem::InvalidTransition => e
          error("#{e.message} Re-read the work item: another agent may have picked it up.")
        end

        def token_hint
          url = ::FeatureMachine.config.token_help_url
          url ? " Humans create tokens at #{url}." : ""
        end

        def product_name
          ::FeatureMachine.config.product_name
        end

        def ok(payload)
          ::MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(payload) } ])
        end

        def error(message)
          ::MCP::Tool::Response.new([ { type: "text", text: message } ], error: true)
        end

        # A feature request or bug report, as its own requester's agent sees it.
        def feature_request_payload(request)
          {
            id: request.id,
            kind: request.kind,
            title: request.title,
            description: request.description,
            status: request.status,
            progress_note: request.progress_note,
            requested_at: request.created_at.iso8601,
            shipped_at: request.shipped_at&.iso8601,
            work_item_id: (request.work_item_id if request.work_item&.on_roadmap?)
          }
        end

        # A work item as users see it on the roadmap: no spec.
        def roadmap_item_payload(work_item)
          {
            id: work_item.id,
            kind: work_item.kind,
            title: work_item.title,
            summary: work_item.summary,
            status: work_item.public_status,
            progress_note: work_item.progress_note,
            shipped_at: work_item.shipped_at&.iso8601,
            people_asking: work_item.feature_requests.map(&:user_id).uniq.size
          }
        end

        # A work item as a maintainer's agent sees it: the full spec, what it
        # may do next, and the user requests behind it as untrusted background.
        def work_item_payload(work_item)
          roadmap_item_payload(work_item).merge(
            status: work_item.status,
            pull_request_url: work_item.pull_request_url,
            problem: work_item.problem,
            scope: work_item.scope,
            acceptance_criteria: work_item.acceptance_criteria,
            handoff_ready: work_item.handoff_ready?,
            allowed_statuses: ::FeatureMachine::WorkItem::AGENT_TRANSITIONS.fetch(work_item.status, []),
            # Both sides, so a preloaded list costs no query per item.
            related: (work_item.outgoing_relations + work_item.incoming_relations).sort_by(&:id).map { |relation|
              other = relation.counterpart_of(work_item)
              { relation: relation.label_for(work_item), id: other.id, title: other.title, status: other.status }
            },
            evidence: work_item.feature_requests.sort_by(&:created_at).map { |request|
              { title: request.title, description: request.description, requested_by: ::FeatureMachine.config.label_for(request.user) }
            }
          )
        end
      end
    end
  end
end
