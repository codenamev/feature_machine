require_relative "boot"

require "rails"
require "active_record/railtie"
require "action_controller/railtie"
require "active_job/railtie"
require "ruby_llm"
require "neighbor"
require "feature_machine"

module Dummy
  class Application < Rails::Application
    config.load_defaults 8.1
    config.root = File.expand_path("..", __dir__)
    config.eager_load = false
    config.secret_key_base = "feature_machine-dummy"
    config.active_support.deprecation = :stderr
    # test_helper builds the schema itself: users, then the engine's migrations.
    config.active_record.maintain_test_schema = false
    # As a host's config/environments/test.rb would: forms post without a token.
    config.action_controller.allow_forgery_protection = false
  end
end
