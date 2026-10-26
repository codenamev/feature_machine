# feature_machine: the feature-request -> triage -> work-item -> agent loop,
# on its way out of this app and into a mountable engine (nowreading#102).
#
# The gem's entry point. The host loads it by path from its Gemfile, so
# Bundler.require runs it before the application class exists and the
# namespace is there before Zeitwerk descends into app/*/feature_machine/.
# Everything under FeatureMachine:: in the host's app/ is the engine's code
# until phase 5b moves it here; this file and lib/feature_machine/ are its
# configuration and host seams.
require_relative "feature_machine/version"
require_relative "feature_machine/configuration"
require_relative "feature_machine/auth"
require_relative "feature_machine/engine"
require_relative "feature_machine/routes"

module FeatureMachine
  # The Rack env key every engine controller and MCP tool reads its credential
  # from. The middlewares in FeatureMachine::Auth set it; a host with its own
  # authentication middleware can set it directly instead.
  ENV_KEY = "feature_machine.credential".freeze

  # The three scopes the engine asks about. A host's token model may know
  # twenty; the engine only ever asks these.
  READ       = "read".freeze
  WRITE      = "write".freeze
  MAINTAINER = "maintainer".freeze
  SCOPES     = [ READ, WRITE, MAINTAINER ].freeze

  class << self
    def config
      @config ||= Configuration.new
    end

    def configure
      yield config
      config
    end

    # Tests only: forget the host's configuration.
    def reset_config!
      @config = nil
    end
  end
end
