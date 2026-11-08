require "test_helper"

class FeatureMachine::RequestStatusTest < ActiveSupport::TestCase
  def request_record
    FeatureMachine::Request.create!(user: users(:one), title: "Dark mode for the dashboard")
  end

  def work_item(status = "planned")
    FeatureMachine::WorkItem.create!(title: "Dark mode for the dashboard", summary: "Dark mode", status: status)
  end

  test "an unattached request moves between requested and declined" do
    request = request_record
    assert request.update(status: "declined")
    assert request.update(status: "requested")
  end

  test "an unattached request cannot take a work item status directly" do
    request = request_record
    %w[planned in_progress shipped].each do |status|
      assert_not request.update(status: status), status
      assert_includes request.errors[:status], "can only be set to requested or declined"
      request.reload
    end
  end

  test "an attached request's status follows its work item" do
    request = request_record
    request.update!(work_item: work_item("planned"))
    assert request.planned?

    assert_not request.update(status: "declined")
    assert_includes request.errors[:status], "follows its work item"
  end

  test "a status sent along with a work item change is overridden by the item" do
    request = request_record
    assert request.update(work_item: work_item("planned"), status: "shipped")
    assert request.reload.planned?

    assert request.update(work_item: nil, status: "shipped")
    assert request.reload.requested?
  end
end
