require "test_helper"

# The engine's auth seam at the Rack level: the two middlewares and the rule
# that decides what a credential may do. No controllers involved.
class FeatureMachine::AuthTest < ActiveSupport::TestCase
  FakeCredential = Struct.new(:user, :scopes) do
    def allows?(scope) = scopes.include?(scope.to_s)
  end

  setup do
    @config = FeatureMachine.config
    @saved = { current_user: @config.current_user, admin: @config.admin, authenticate_api: @config.authenticate_api, session_auth: @config.session_auth }

    # The host's seams, in test form: the user rides on the env, admin is a flag.
    @config.current_user     = ->(request) { request.env["test.user"] }
    @config.admin            = ->(user) { user.admin? }
    @config.authenticate_api = ->(token) { token == "good" ? FakeCredential.new(users(:two), %w[read write]) : nil }
    @config.session_auth     = true

    @inner = ->(env) { [ 200, {}, [ env[FeatureMachine::ENV_KEY].class.name ] ] }
  end

  teardown do
    @saved.each { |key, value| @config.public_send("#{key}=", value) }
  end

  # Session

  test "an anonymous session carries a credential with no user that allows nothing" do
    credential = run_session({})
    assert_instance_of FeatureMachine::Auth::SessionCredential, credential
    assert_nil credential.user
    refute credential.allows?("read")
  end

  test "a signed-in user may read and write, and maintain only as an admin" do
    user = users(:two)
    credential = run_session("test.user" => user)
    assert_equal user, credential.user
    assert credential.allows?("read")
    assert credential.allows?(:write)
    refute credential.allows?("maintainer")

    user.update!(admin: true)
    assert run_session("test.user" => user).allows?("maintainer")
  end

  test "the session credential resolves its user once, and only when asked" do
    calls = 0
    @config.current_user = ->(_request) { calls += 1; users(:two) }
    credential = run_session({})
    assert_equal 0, calls
    credential.user
    credential.allows?("read")
    assert_equal 1, calls
  end

  test "session auth off sets nothing" do
    @config.session_auth = false
    assert_nil run_session({})
  end

  test "the session middleware never replaces a credential set earlier in the stack" do
    env = { FeatureMachine::ENV_KEY => :already_there }
    FeatureMachine::Auth::Session.new(@inner).call(env)
    assert_equal :already_there, env[FeatureMachine::ENV_KEY]
  end

  # Bearer

  test "a valid bearer token sets the resolved credential" do
    credential = run_bearer("HTTP_AUTHORIZATION" => "Bearer good")
    assert_instance_of FakeCredential, credential
    assert_equal users(:two), credential.user
  end

  test "a bad or missing token sets nothing, so the request falls through to the session" do
    assert_nil run_bearer("HTTP_AUTHORIZATION" => "Bearer bad")
    assert_nil run_bearer({})
    assert_nil run_bearer("HTTP_AUTHORIZATION" => "Basic Zm9vOmJhcg==")

    stacked = FeatureMachine::Auth::Bearer.new(FeatureMachine::Auth::Session.new(@inner))
    env = { "HTTP_AUTHORIZATION" => "Bearer bad", "test.user" => users(:two) }
    stacked.call(env)
    assert_instance_of FeatureMachine::Auth::SessionCredential, env[FeatureMachine::ENV_KEY]
    assert_equal users(:two), env[FeatureMachine::ENV_KEY].user
  end

  test "bearer does nothing until the host configures authenticate_api" do
    @config.authenticate_api = nil
    assert_nil run_bearer("HTTP_AUTHORIZATION" => "Bearer good")
  end

  test "bearer_token reads the scheme case-insensitively and ignores other schemes" do
    assert_equal "abc", FeatureMachine::Auth.bearer_token("HTTP_AUTHORIZATION" => "bearer abc")
    assert_equal "abc", FeatureMachine::Auth.bearer_token("HTTP_AUTHORIZATION" => "Bearer  abc ")
    assert_nil FeatureMachine::Auth.bearer_token("HTTP_AUTHORIZATION" => "Bearer")
    assert_nil FeatureMachine::Auth.bearer_token({})
  end

  # The rule

  test "allows? trusts the credential for read and write" do
    credential = FakeCredential.new(users(:two), %w[read])
    assert FeatureMachine::Auth.allows?(credential, "read")
    refute FeatureMachine::Auth.allows?(credential, :write)
    refute FeatureMachine::Auth.allows?(nil, "read")
  end

  test "allows? re-checks the host's admin predicate before granting maintainer" do
    user = users(:two)
    credential = FakeCredential.new(user, %w[read write maintainer])
    refute FeatureMachine::Auth.allows?(credential, "maintainer"), "a credential's own word is not enough"

    user.update!(admin: true)
    assert FeatureMachine::Auth.allows?(credential, "maintainer")
  end

  private

  def run_session(env)
    FeatureMachine::Auth::Session.new(@inner).call(env)
    env[FeatureMachine::ENV_KEY]
  end

  def run_bearer(env)
    FeatureMachine::Auth::Bearer.new(@inner).call(env)
    env[FeatureMachine::ENV_KEY]
  end
end
