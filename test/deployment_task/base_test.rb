# frozen_string_literal: true

require_relative "../test_helper"

class BaseTest < Minitest::Test
  include TaskTestHelper

  # --- Unit tests for Base (Task 2.7) ---
  # Requirements: 3.1, 3.2

  def test_execute_raises_not_implemented_error
    base_instance = DeploymentTask::Base.new
    assert_raises(NotImplementedError) { base_instance.execute }
  end

  def test_task_name_returns_underscored_name
    # Create a named class to test task_name
    klass = Class.new(DeploymentTask::Base)
    # Assign a constant name so demodulize works
    Object.const_set(:MyFancyDeployTask, klass)
    begin
      assert_equal "my_fancy_deploy_task", klass.task_name
    ensure
      Object.send(:remove_const, :MyFancyDeployTask)
    end
  end

  def test_task_name_returns_nil_for_anonymous_class
    klass = Class.new(DeploymentTask::Base)
    # Anonymous classes have nil name, so task_name returns nil
    assert_nil klass.task_name
  end

  def test_dry_run_description_returns_task_description
    klass = create_task_class(
      version: generate_version,
      phase: :post_deploy,
      description: "Run data backfill"
    )
    instance = klass.new
    assert_equal "Run data backfill", instance.dry_run_description
  end

  def test_version_phase_description_dsl_sets_metadata
    klass = create_task_class(
      version: "20250601120000",
      phase: :pre_deploy,
      description: "Test DSL"
    )
    assert_equal "20250601120000", klass.task_version
    assert_equal :pre_deploy, klass.task_phase
    assert_equal "Test DSL", klass.task_description
  end
end
