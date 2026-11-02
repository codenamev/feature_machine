module FeatureMachine
  module Mcp
    class ReadRoadmap < Base
      tool_name "read_roadmap"
      description "The roadmap and changelog: work that is in progress or planned, then features " \
                  "shipped and bugs fixed, newest first. Each entry has a summary and how many people asked. " \
                  "A request's `work_item_id` (from list_feature_requests / list_bug_reports) matches an entry's `id`."
      input_schema(properties: {}, required: [])
      annotations(read_only_hint: true)

      def self.call(server_context: nil)
        with_user(server_context, scope: ::FeatureMachine::READ) do |_user, _credential|
          roadmap = ::FeatureMachine::Roadmap.new
          ok(
            upcoming: roadmap.upcoming.values.flatten.map { |item| roadmap_item_payload(item) },
            changelog: roadmap.changelog.values.flatten.map { |item| roadmap_item_payload(item) }
          )
        end
      end
    end
  end
end
