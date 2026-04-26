# frozen_string_literal: true

require_relative "../test_helper"
require "rantly"
require "rantly/property"

class ConfigurationTest < Minitest::Test
  include TaskTestHelper

  # Feature: deployment-task-gem, Property 1: Configuration round-trip
  # **Validates: Requirements 2.1**
  def test_configuration_round_trip_property
    property_of {
      [string, string, choose(:database, :none)]
    }.check(100) { |task_directory, record_base_class, lock_adapter|
      DeploymentTask.reset!

      DeploymentTask.configure do |config|
        config.task_directory = task_directory
        config.record_base_class = record_base_class
        config.lock_adapter = lock_adapter
      end

      cfg = DeploymentTask.configuration
      assert_equal task_directory, cfg.task_directory
      assert_equal record_base_class, cfg.record_base_class
      assert_equal lock_adapter, cfg.lock_adapter
    }
  end

  # --- Unit tests for Configuration defaults (Task 1.5) ---
  # Requirements: 2.6

  def test_default_task_directory
    config = DeploymentTask::Configuration.new
    assert_equal "lib/deployment_task/tasks", config.task_directory
  end

  def test_default_error_reporter_is_callable_noop
    config = DeploymentTask::Configuration.new
    assert_respond_to config.error_reporter, :call
    # Should not raise when called
    config.error_reporter.call(StandardError.new("test"), {})
  end

  def test_default_logger_is_logger_compatible
    config = DeploymentTask::Configuration.new
    assert_respond_to config.logger, :info
  end

  def test_default_record_base_class
    config = DeploymentTask::Configuration.new
    assert_equal "ApplicationRecord", config.record_base_class
  end

  def test_default_lock_adapter
    config = DeploymentTask::Configuration.new
    assert_equal :database, config.lock_adapter
  end

  def test_reset_restores_defaults
    DeploymentTask.configure do |config|
      config.task_directory = "/custom/path"
      config.record_base_class = "CustomRecord"
      config.lock_adapter = :none
    end

    assert_equal "/custom/path", DeploymentTask.configuration.task_directory

    DeploymentTask.reset!

    config = DeploymentTask.configuration
    assert_equal "lib/deployment_task/tasks", config.task_directory
    assert_equal "ApplicationRecord", config.record_base_class
    assert_equal :database, config.lock_adapter
  end

  private

  def property_of(&block)
    Rantly::Property.new(block)
  end
end
