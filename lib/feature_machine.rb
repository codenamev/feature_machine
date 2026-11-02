# feature_machine: the feature-request -> triage -> work-item -> agent loop,
# packaged as a Rails engine.
#
# The gem's entry point. The host loads it from its Gemfile, so
# Bundler.require runs it before the application class exists and the
# namespace is there before Zeitwerk descends into app/*/feature_machine/.
# This file and lib/feature_machine/ are the engine's configuration and host
# seams.
#
# Require the runtime gems the engine names at boot (the prompts initializer
# touches RubyLLM::Prompt). A host may load them already; a fresh
# host that only adds feature_machine doesn't, and fails to boot without these.
require "ruby_llm"
require "neighbor"
require "jbuilder"
require "mcp"
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
