# frozen_string_literal: true

require_relative "test_helper"

class SmokeTest < Minitest::Test
  include TaskTestHelper

  def test_test_helper_loads_successfully
    assert defined?(DeploymentTask), "DeploymentTask module should be defined"
    assert defined?(DeploymentTask::Base), "DeploymentTask::Base should be defined"
    assert defined?(DeploymentTask::Record), "DeploymentTask::Record should be defined"
    assert defined?(DeploymentTask::Registry), "DeploymentTask::Registry should be defined"
    assert defined?(DeploymentTask::Runner), "DeploymentTask::Runner should be defined"
  end

  def test_sqlite_database_is_connected
    assert ActiveRecord::Base.connected?, "ActiveRecord should be connected"
    assert ActiveRecord::Base.connection.table_exists?(:deployment_task_records),
      "deployment_task_records table should exist"
  end

  def test_create_task_class_helper_works
    klass = create_task_class(version: generate_version, phase: :post_deploy)
    assert klass < DeploymentTask::Base, "Created class should inherit from Base"
    assert_equal :post_deploy, klass.task_phase
    assert_instance_of String, klass.task_version
  end

  def test_record_can_be_created
    record = DeploymentTask::Record.create!(
      version: "20250101120000",
      phase: "post_deploy",
      task_name: "test_task"
    )
    assert record.persisted?
    assert_equal "pending", record.status
  end

  def test_state_resets_between_tests
    # Registry should be empty after reset
    assert_empty DeploymentTask::Registry.all_tasks
    # Records should be cleared
    assert_equal 0, DeploymentTask::Record.count
  end
end
