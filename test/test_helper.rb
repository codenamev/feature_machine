# The engine's suite runs against test/dummy, a host app with only what the
# engine needs from one: a users table with an admin flag.
ENV["RAILS_ENV"] = "test"

require_relative "dummy/config/environment"
require "rails/test_help"

ActiveRecord::Schema.verbose = false
# Start from an empty database every run: schema.rb only rebuilds users, so a
# kept schema_migrations would skip the migration that adds users.admin.
ActiveRecord::Tasks::DatabaseTasks.purge(ActiveRecord::Base.connection_db_config)
load File.expand_path("dummy/db/schema.rb", __dir__)
ActiveRecord::Base.connection_pool.migration_context.migrate

class ActiveSupport::TestCase
  self.fixture_paths = [ File.expand_path("fixtures", __dir__) ]
  fixtures :all
end
