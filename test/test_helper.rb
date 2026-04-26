# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/test/"
end

require "minitest/autorun"

# Set up ActiveRecord with in-memory SQLite BEFORE loading the gem,
# since DeploymentTask::Record inherits from ActiveRecord::Base.
require "active_record"
require "aasm"

ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: ":memory:"
)

# Silence migration output in tests
ActiveRecord::Migration.verbose = false

# Run the migration to create the deployment_task_records table
require_relative "../db/migrate/001_create_deployment_task_records"
CreateDeploymentTaskRecords.migrate(:up)

# Now load the gem (engine.rb will be loaded since Rails is defined via railties,
# but that's fine — the Engine just sets up initializers that won't run in test)
require_relative "../lib/deployment_task"

# Explicitly require the Record model — in a real Rails app this is autoloaded
# by the engine, but in test we need to load it manually.
require_relative "../app/models/deployment_task/record"

# Load shared test support helpers
Dir[File.join(__dir__, "support", "**", "*.rb")].sort.each { |f| require f }

# Reset DeploymentTask state between tests
module DeploymentTaskTestLifecycle
  def setup
    super
    DeploymentTask.reset!
    DeploymentTask::Record.delete_all
    # Use :none lock adapter since we're on SQLite in tests
    DeploymentTask.configure do |config|
      config.lock_adapter = :none
      config.logger = nil # suppress log noise in tests
    end
  end
end

# Apply lifecycle hooks to all Minitest::Test subclasses
Minitest::Test.prepend(DeploymentTaskTestLifecycle)
