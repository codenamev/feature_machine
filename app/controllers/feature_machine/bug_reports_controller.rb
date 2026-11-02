# Bug reports are requests of kind `bug`, taken in through their own door,
# because a bug asks a different question than a feature does.
class FeatureMachine::BugReportsController < FeatureMachine::BaseController
  # "Your bug reports": only ever the signed-in user's own, since a report can
  # describe their data.
  def index
    @bug_reports = ::FeatureMachine::Request.owned_by(feature_machine_user).bug.includes(:work_item).newest_first
  end

  def new
    @bug_report = ::FeatureMachine::Request.bug.new
  end

  def create
    @bug_report = ::FeatureMachine::Request.owned_by(feature_machine_user).bug.build(bug_report_params)

    if @bug_report.save
      redirect_to bug_reports_path, notice: "Thanks. Only you can see this report; its status will update here."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def bug_report_params
    params.expect(bug_report: [ :title, :description ])
  end
end
