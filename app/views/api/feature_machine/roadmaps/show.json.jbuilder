json.generated_at Time.current.iso8601
json.statuses     FeatureMachine::WorkItem::UPCOMING + %w[shipped]

json.upcoming do
  json.array! @roadmap.upcoming.values.flatten, partial: "api/feature_machine/roadmaps/work_item", as: :work_item
end

json.changelog do
  json.array! @roadmap.changelog.values.flatten, partial: "api/feature_machine/roadmaps/work_item", as: :work_item
end
