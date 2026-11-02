module FeatureMachine
  # The roadmap as shown to users and their agents: upcoming work items by
  # status, then shipped ones as a changelog by month. It is read straight from
  # work items, so it is current the moment a status changes.
  class Roadmap
    # @return [Hash{String => Array<WorkItem>}] in_progress then planned, empty sections included
    def upcoming
      @upcoming ||= begin
        grouped = WorkItem.upcoming.includes(:feature_requests).newest_first.group_by(&:public_status)
        WorkItem::UPCOMING.index_with { |status| grouped.fetch(status, []) }
      end
    end

    # @return [Hash{Date => Array<WorkItem>}] first day of each month => items shipped in it, newest first
    def changelog
      @changelog ||= WorkItem.changelog.includes(:feature_requests)
        .group_by { |item| item.shipped_at.beginning_of_month.to_date }
    end

    def empty?
      upcoming.values.all?(&:empty?) && changelog.empty?
    end
  end
end
