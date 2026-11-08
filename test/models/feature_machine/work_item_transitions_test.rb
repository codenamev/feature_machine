require "test_helper"

class FeatureMachine::WorkItemTransitionsTest < ActiveSupport::TestCase
  def item(status)
    FeatureMachine::WorkItem.create!(title: "Dark mode for the dashboard", summary: "Dark mode", status: status, pull_request_url: "https://github.com/o/r/pull/1")
  end

  test "every move in the table saves; every other move is refused" do
    statuses = FeatureMachine::WorkItem.statuses.keys
    statuses.each do |from|
      statuses.excluding(from).each do |to|
        work_item = item(from)
        work_item.status = to
        allowed = FeatureMachine::WorkItem::TRANSITIONS.fetch(from).include?(to)
        assert_equal allowed, work_item.save, "#{from} -> #{to}"
        assert_includes work_item.errors[:status].join, "can't move from" unless allowed
      end
    end
  end

  test "the agent table is a subset of the full table" do
    FeatureMachine::WorkItem::AGENT_TRANSITIONS.each do |from, tos|
      assert_empty tos - FeatureMachine::WorkItem::TRANSITIONS.fetch(from), from
    end
  end

  test "shipped_at is stamped on the way in and cleared on the way out" do
    work_item = item("in_progress")
    work_item.update!(status: "shipped")
    first = work_item.shipped_at
    assert first

    work_item.update!(status: "in_progress")
    assert_nil work_item.shipped_at

    travel 1.day do
      work_item.update!(status: "shipped")
      assert_operator work_item.shipped_at, :>, first
    end
  end

  test "a declined item has to go back through draft" do
    work_item = item("declined")
    assert_not work_item.update(status: "shipped")
    assert_equal %w[draft], work_item.next_statuses
  end
end
