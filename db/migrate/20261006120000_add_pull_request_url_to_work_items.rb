# The pull request that implements a work item, attached by the agent that
# opened it when it hands the work back for review.
class AddPullRequestUrlToWorkItems < ActiveRecord::Migration[8.1]
  def change
    add_column :work_items, :pull_request_url, :string
  end
end
