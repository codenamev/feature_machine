# A work item as users see it. The spec (problem, scope, acceptance criteria)
# is the maintainer's working document and is not included.
json.id            work_item.id
json.kind          work_item.kind
json.title         work_item.title
json.summary       work_item.summary
json.status        work_item.public_status
json.progress_note work_item.progress_note
json.shipped_at    work_item.shipped_at&.iso8601
json.updated_at    work_item.updated_at.iso8601
json.people_asking work_item.feature_requests.map(&:user_id).uniq.size
json.url           roadmap_url(anchor: dom_id(work_item))
