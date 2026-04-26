# frozen_string_literal: true

require_relative "../test_helper"

# Rails is not defined by the default test_helper, so we need to
# explicitly require it to make Rails::Engine available, then load
# the engine file which was skipped during test_helper setup.
require "rails"
require_relative "../../lib/deployment_task/engine"

class EngineTest < Minitest::Test
  # Validates: Requirements 1.2
  def test_engine_is_a_subclass_of_rails_engine
    assert DeploymentTask::Engine < ::Rails::Engine,
      "DeploymentTask::Engine should be a subclass of Rails::Engine"
  end

  # Validates: Requirements 1.2
  def test_engine_isolates_deployment_task_namespace
    assert DeploymentTask::Engine.isolated?,
      "DeploymentTask::Engine should use isolate_namespace"
  end
end
