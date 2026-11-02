# The roadmap and changelog: what is being built, what is queued, and what
# shipped. It lists work items, not raw requests, so it reads as a product
# changelog rather than a suggestion box. Signed-in users only; agents read
# the same thing at GET /api/roadmap with a token.
class FeatureMachine::RoadmapController < FeatureMachine::BaseController
  def show
    @roadmap = ::FeatureMachine::Roadmap.new
  end
end
