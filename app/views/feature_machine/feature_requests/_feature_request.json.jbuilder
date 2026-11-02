# The one JSON shape for a feature request or bug report, as its own
# requester's agent sees it.
json.id            feature_request.id
json.kind          feature_request.kind
json.title         feature_request.title
json.description   feature_request.description
json.status        feature_request.status
json.progress_note feature_request.progress_note
json.requested_by  FeatureMachine.config.label_for(feature_request.user)
json.requested_at  feature_request.created_at.iso8601
json.updated_at    feature_request.updated_at.iso8601
json.shipped_at    feature_request.shipped_at&.iso8601
json.url           feature_request.bug? ? bug_reports_url(anchor: dom_id(feature_request)) : feature_requests_url(anchor: dom_id(feature_request))
# The roadmap entry this was bucketed into, once that work is planned.
json.work_item_id  (feature_request.work_item_id if feature_request.work_item&.on_roadmap?)
