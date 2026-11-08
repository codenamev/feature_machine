require "test_helper"

# Every surface, through a host that brings only what the README asks for:
# an ApplicationController, a users table, and the three config lambdas. The
# dummy defines no current_user, no Admin::BaseController and no
# Api::BaseController, so anything the engine still borrows from a host fails
# here first.
class FeatureMachine::FreshHostTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  Credential = Struct.new(:user, :scopes) do
    def allows?(scope) = scopes.include?(scope.to_s)
  end

  setup do
    @config = FeatureMachine.config
    @saved = %i[current_user authenticate_api].index_with { |key| @config.public_send(key) }

    # Who is signed in rides on a header; tokens name a user and their scopes.
    @config.current_user = ->(request) { User.find_by(id: request.headers["X-Test-User"]) }
    tokens = {
      "user" => Credential.new(users(:one), %w[read write]),
      "fake-maintainer" => Credential.new(users(:two), %w[read write maintainer]),
      "maintainer" => Credential.new(users(:maintainer), %w[read write maintainer])
    }
    @config.authenticate_api = ->(token) { tokens[token] }
  end

  teardown do
    @saved.each { |key, value| @config.public_send("#{key}=", value) }
  end

  test "a signed-out visitor gets a 401 when the host has no sign-in page" do
    get "/feature-requests"
    assert_response :unauthorized
  end

  test "a user files and follows feature requests and bug reports" do
    get "/feature-requests/new", headers: as(:one)
    assert_response :success

    post "/feature-requests", params: { feature_request: { title: "Dark mode for the dashboard" } }, headers: as(:one)
    assert_redirected_to "/feature-requests"
    follow_redirect!(headers: as(:one))
    assert_select "[data-slot=flash-notice]", "Thanks. Its status will update here."
    post "/bug-reports", params: { bug_report: { title: "Save button does nothing on mobile" } }, headers: as(:one)
    assert_redirected_to "/bug-reports"

    request, bug = FeatureMachine::Request.owned_by(users(:one)).order(:id).to_a
    assert request.feature?
    assert bug.bug?

    get "/feature-requests", headers: as(:one)
    assert_select "##{ActionView::RecordIdentifier.dom_id(request)}"
    get "/bug-reports", headers: as(:one)
    assert_select "##{ActionView::RecordIdentifier.dom_id(bug)}"

    get "/feature-requests", headers: as(:two)
    assert_select "##{ActionView::RecordIdentifier.dom_id(request)}", count: 0
  end

  test "pages inline the default cn-* stylesheet once, in a layer, unless turned off" do
    get "/feature-requests/new", headers: as(:one)
    assert_select "style", count: 1
    assert_includes css_block, "@layer feature_machine"
    assert_includes css_block, ".cn-button"

    @config.default_stylesheet = false
    get "/feature-requests/new", headers: as(:one)
    assert_select "style", count: 0
  ensure
    @config.default_stylesheet = true
  end

  test "an invalid request re-renders the form" do
    post "/feature-requests", params: { feature_request: { title: "x" } }, headers: as(:one)
    assert_response :unprocessable_entity
  end

  test "admin pages 404 for anyone config.admin doesn't vouch for" do
    %w[/admin/triage /admin/work_items].each do |path|
      get path, headers: as(:one)
      assert_response :not_found, path
    end
  end

  test "triage to roadmap to changelog" do
    first  = file_request(:one, "Dark mode for the dashboard")
    second = file_request(:two, "Night theme please, my eyes")

    get "/admin/triage", headers: as(:maintainer)
    assert_response :success
    assert_select ".triage-bucket", 2

    post "/admin/work_items", params: { request_ids: [ first.id ] }, headers: as(:maintainer)
    work_item = FeatureMachine::WorkItem.last
    assert_redirected_to "/admin/work_items/#{work_item.id}/edit"

    post "/admin/attachments", params: { work_item_id: work_item.id, request_ids: [ second.id ] }, headers: as(:maintainer)
    assert_redirected_to "/admin/triage"
    assert_equal work_item, second.reload.work_item

    patch "/admin/work_items/#{work_item.id}", params: { work_item: { summary: "Dark mode", acceptance_criteria: "- toggles", status: "planned" } }, headers: as(:maintainer)
    assert_redirected_to "/admin/work_items/#{work_item.id}"
    %W[/admin/work_items /admin/work_items/#{work_item.id} /admin/work_items/#{work_item.id}.md].each do |path|
      get path, headers: as(:maintainer)
      assert_response :success, path
    end

    get "/roadmap", headers: as(:one)
    assert_select "##{ActionView::RecordIdentifier.dom_id(work_item)}"

    patch "/admin/work_items/#{work_item.id}", params: { work_item: { status: "shipped" } }, headers: as(:maintainer)
    get "/roadmap", headers: as(:one)
    assert_select "#changelog"
    assert first.reload.shipped?

    late = file_request(:two, "Dark mode, but for emails too")
    post "/admin/attachments", params: { work_item_id: work_item.id, request_ids: [ late.id ] }, headers: as(:maintainer)
    assert_response :not_found, "a shipped item takes no new requests"
    assert_nil late.reload.work_item
  end

  test "models configured without provider keys degrade instead of failing" do
    saved = %i[embedding_model drafter_model judgment_model].index_with { |key| @config.public_send(key) }
    @config.embedding_model = "text-embedding-3-small"
    @config.drafter_model   = "gpt-4.1-mini"
    @config.judgment_model  = "gpt-4.1-mini"

    perform_enqueued_jobs do
      post "/feature-requests", params: { feature_request: { title: "Dark mode for the dashboard" } }, headers: as(:one)
    end
    assert_redirected_to "/feature-requests"

    get "/admin/triage", headers: as(:maintainer)
    assert_response :success
    assert_select ".triage-bucket__judgment", 0

    post "/admin/work_items", params: { request_ids: FeatureMachine::Request.pluck(:id) }, headers: as(:maintainer)
    assert_match "model was unavailable", flash[:notice]
  ensure
    saved&.each { |key, value| @config.public_send("#{key}=", value) }
  end

  test "the API serves a user's agent with nothing borrowed from the host" do
    post "/api/feature_requests", params: { feature_request: { title: "Export as CSV please" } }, headers: bearer("user"), as: :json
    assert_response :created
    assert_equal "user ##{users(:one).id}", response.parsed_body["requested_by"]

    post "/api/bug_reports", params: { bug_report: { title: "Login link expires too fast" } }, headers: bearer("user"), as: :json
    assert_response :created

    get "/api/feature_requests", headers: bearer("user")
    assert_equal 1, response.parsed_body["requests"].size
    get "/api/bug_reports", headers: bearer("user")
    assert_equal 1, response.parsed_body["requests"].size
    get "/api/roadmap", headers: bearer("user")
    assert_response :success

    get "/api/feature_requests", headers: { "Accept" => "application/json" }
    assert_response :unauthorized
    assert_equal "unauthorized", response.parsed_body["code"]

    post "/api/feature_requests", params: { nope: 1 }, headers: bearer("user")
    assert_response :bad_request
    assert_equal "parameter_missing", response.parsed_body["code"]
  end

  test "maintainer endpoints need the host's admin to agree with the token" do
    %w[/api/work_items /api/maintainer/feature_requests].each do |path|
      get path, headers: bearer("user")
      assert_response :forbidden, path
      get path, headers: bearer("fake-maintainer")
      assert_response :forbidden, path
      get path, headers: bearer("maintainer")
      assert_response :success, path
    end
  end

  test "an agent picks up planned work and hands it back for review" do
    work_item = FeatureMachine::WorkItem.create!(title: "Dark mode for everyone", summary: "Dark mode", status: :planned)

    get "/api/work_items/#{work_item.id}", headers: bearer("maintainer")
    assert_response :success

    patch "/api/work_items/#{work_item.id}", params: { work_item: { status: "in_progress" } }, headers: bearer("maintainer"), as: :json
    assert_response :success
    patch "/api/work_items/#{work_item.id}", params: { work_item: { status: "in_progress" } }, headers: bearer("maintainer"), as: :json
    assert_response :conflict

    patch "/api/work_items/#{work_item.id}", params: { work_item: { status: "in_review", pull_request_url: "https://github.com/o/r/pull/1" } }, headers: bearer("maintainer"), as: :json
    assert_response :success
    assert work_item.reload.in_review?
  end

  test "MCP: users see five tools, maintainers eight, and a session cookie is no credential" do
    assert_equal %w[list_bug_reports list_feature_requests read_roadmap report_bug request_feature], mcp_tool_names("user").sort
    assert_equal 8, mcp_tool_names("maintainer").size

    mcp_call("user", "request_feature", title: "Keyboard shortcuts for triage")
    assert_not mcp_result["isError"], mcp_result.inspect
    assert_equal 1, FeatureMachine::Request.owned_by(users(:one)).count

    mcp_call("user", "list_work_items")
    assert_match "Tool not found", response.parsed_body.dig("error", "data")

    post "/mcp", params: { jsonrpc: "2.0", id: 1, method: "tools/call", params: { name: "list_feature_requests", arguments: {} } }.to_json,
                 headers: as(:one).merge("Content-Type" => "application/json")
    assert mcp_result["isError"]
  end

  test "MCP: the fulfilment agent's three tools" do
    work_item = FeatureMachine::WorkItem.create!(title: "Dark mode for everyone", summary: "Dark mode", status: :planned)

    blocker = FeatureMachine::WorkItem.create!(title: "Theme tokens", summary: "Tokens", status: :planned)
    FeatureMachine::WorkItemRelation.create!(from_work_item: blocker, to_work_item: work_item, kind: "blocks")

    mcp_call("maintainer", "list_work_items")
    items = JSON.parse(mcp_result.dig("content", 0, "text"))["work_items"].index_by { _1["id"] }
    assert_equal [ work_item.id, blocker.id ], items.keys
    assert_equal [ { "relation" => "is blocked by", "id" => blocker.id, "title" => "Theme tokens", "status" => "planned" } ], items[work_item.id]["related"]
    assert_equal [ "blocks" ], items[blocker.id]["related"].map { _1["relation"] }

    mcp_call("maintainer", "get_work_item", id: work_item.id)
    assert_not mcp_result["isError"]

    mcp_call("maintainer", "update_work_item", id: work_item.id, status: "in_progress")
    assert_not mcp_result["isError"]
    assert work_item.reload.in_progress?
  end

  private

  def as(fixture) = { "X-Test-User" => users(fixture).id.to_s }

  def css_block = css_select("style").first.text

  def bearer(token) = { "Authorization" => "Bearer #{token}", "Accept" => "application/json" }

  def file_request(fixture, title)
    FeatureMachine::Request.create!(user: users(fixture), title: title)
  end

  def mcp_call(token, name, **arguments)
    post "/mcp", params: { jsonrpc: "2.0", id: 1, method: "tools/call", params: { name: name, arguments: arguments } }.to_json,
                 headers: bearer(token).merge("Content-Type" => "application/json")
  end

  def mcp_tool_names(token)
    post "/mcp", params: { jsonrpc: "2.0", id: 1, method: "tools/list" }.to_json, headers: bearer(token).merge("Content-Type" => "application/json")
    mcp_result["tools"].map { _1["name"] }
  end

  def mcp_result = response.parsed_body["result"]
end
