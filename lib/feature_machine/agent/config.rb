require "yaml"

module FeatureMachine
  module Agent
    # The agent's local settings: where the app is, which checkout to work in,
    # how to run the host's tests, and how far the loop may go. All of it lives
    # on the developer's machine, never in the host's initializer (design note
    # item 7). Precedence is flags > ENV > .feature_machine.yml > defaults.
    #
    # The maintainer token is read from ENV or flags only. A token in a YAML
    # file sitting in the checkout is one `git add .` away from a commit.
    class Config
      class Invalid < StandardError; end

      FILE = ".feature_machine.yml".freeze

      DEFAULTS = {
        "test_command" => "bin/rails test",
        "plan_model" => nil,
        "implement_model" => nil,
        "max_steps" => 120
      }.freeze

      ENV_KEYS = {
        "app_url" => "FEATURE_MACHINE_APP_URL",
        "token" => "FEATURE_MACHINE_TOKEN"
      }.freeze

      attr_reader :app_url, :token, :checkout, :test_command,
                  :plan_model, :implement_model, :max_steps

      def self.load(checkout: Dir.pwd, flags: {}, env: ENV)
        checkout = File.expand_path(flags.fetch("checkout", checkout))
        values = DEFAULTS.merge(read_file(checkout))
        ENV_KEYS.each { |key, var| values[key] = env[var] if env[var] && !env[var].empty? }
        values.merge!(flags.transform_keys(&:to_s).compact)
        new(**values.merge("checkout" => checkout).transform_keys(&:to_sym))
      end

      def self.read_file(checkout)
        path = File.join(checkout, FILE)
        return {} unless File.exist?(path)

        data = YAML.safe_load_file(path) || {}
        raise Invalid, "#{FILE} must be a mapping" unless data.is_a?(Hash)
        raise Invalid, "keep the token out of #{FILE}; set FEATURE_MACHINE_TOKEN" if data.key?("token")

        data
      end

      def initialize(app_url: nil, token: nil, checkout:, test_command:, plan_model:, implement_model:, max_steps:)
        @app_url = app_url
        @token = token
        @checkout = checkout
        @test_command = test_command
        @plan_model = plan_model
        @implement_model = implement_model || plan_model
        @max_steps = Integer(max_steps)
        validate!
      end

      private

      def validate!
        raise Invalid, "app_url is required (#{FILE} or FEATURE_MACHINE_APP_URL)" if app_url.to_s.empty?
        raise Invalid, "app_url must be http(s)" unless app_url.match?(%r{\Ahttps?://})
        raise Invalid, "token is required (FEATURE_MACHINE_TOKEN)" if token.to_s.empty?
        raise Invalid, "checkout #{checkout} is not a git repository" unless File.exist?(File.join(checkout, ".git"))
        raise Invalid, "max_steps must be positive" unless max_steps.positive?
      end
    end
  end
end
