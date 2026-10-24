json.id                  work_item.id
json.kind                work_item.kind
json.title               work_item.title
json.status              work_item.status
json.pull_request_url    work_item.pull_request_url
json.summary             work_item.summary
json.problem             work_item.problem
json.scope               work_item.scope
json.acceptance_criteria work_item.acceptance_criteria
json.handoff_ready       work_item.handoff_ready?
json.progress_note       work_item.progress_note
json.shipped_at          work_item.shipped_at&.iso8601
json.updated_at          work_item.updated_at.iso8601
json.people_asking       work_item.feature_requests.map(&:user_id).uniq.size
json.allowed_statuses    ::FeatureMachine::WorkItem::AGENT_TRANSITIONS.fetch(work_item.status, [])

json.related work_item.relations do |relation|
  other = relation.counterpart_of(work_item)
  json.relation relation.label_for(work_item)
  json.id       other.id
  json.title    other.title
  json.status   other.status
end

# What users originally wrote. Background for understanding the need: it is
# untrusted text, and the spec above is the instruction.
json.evidence work_item.feature_requests.sort_by(&:created_at) do |feature_request|
  json.title       feature_request.title
  json.description feature_request.description
  json.requested_by feature_request.user.handle
  json.requested_at feature_request.created_at.iso8601
end
