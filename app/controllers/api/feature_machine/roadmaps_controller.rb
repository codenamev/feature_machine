# The roadmap and changelog for a signed-up user's agent. Any `read` token
# works; there is no anonymous version.
class Api::FeatureMachine::RoadmapsController < Api::FeatureMachine::BaseController
  before_action :authenticate_user_with_token

  def show
    @roadmap = ::FeatureMachine::Roadmap.new
  end
end
