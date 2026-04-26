# frozen_string_literal: true

require_relative "../test_helper"
require "rantly"
require "rantly/property"
require "stringio"
require "json"
require "logger"

class TaskLoggerTest < Minitest::Test
  include TaskTestHelper

  # Feature: deployment-task-gem, Property 13: Log entries are valid JSON with execution_id
  # **Validates: Requirements 6.1, 6.7**
  def test_log_entries_are_valid_json_with_execution_id
    property_of {
      version = sized(14) { string(:digit) }
      version = "0" * (14 - version.length) + version if version.length < 14
      description = sized(range(1, 50)) { string(:alpha) }
      phase = choose(:pre_deploy, :post_deploy)
      [version, description, phase]
    }.check(100) { |version, description, phase|
      execution_id = SecureRandom.uuid
      logger = DeploymentTask::TaskLogger.new(execution_id: execution_id)

      output = capture_stdout do
        logger.log_task_start(version: version, description: description, phase: phase)
      end

      parsed = JSON.parse(output.strip)
      assert_equal execution_id, parsed["execution_id"]
      assert_equal "task_start", parsed["event"]
    }
  end

  # Feature: deployment-task-gem, Property 14: Log entries contain required fields per event type
  # **Validates: Requirements 6.2, 6.3, 6.4**
  def test_log_entries_contain_required_fields_per_event_type
    property_of {
      version = sized(14) { string(:digit) }
      version = "0" * (14 - version.length) + version if version.length < 14
      description = sized(range(1, 30)) { string(:alpha) }
      phase = choose(:pre_deploy, :post_deploy)
      duration = range(0, 1000).to_f / 100.0
      error_msg = sized(range(1, 30)) { string(:alpha) }
      [version, description, phase, duration, error_msg]
    }.check(100) { |version, description, phase, duration, error_msg|
      execution_id = SecureRandom.uuid
      logger = DeploymentTask::TaskLogger.new(execution_id: execution_id)

      # Test task_start
      start_output = capture_stdout do
        logger.log_task_start(version: version, description: description, phase: phase)
      end
      start_json = JSON.parse(start_output.strip)
      assert_equal version, start_json["version"]
      assert_equal description, start_json["description"]
      assert_equal phase.to_s, start_json["phase"]
      refute_nil start_json["timestamp"]

      # Test task_complete
      complete_output = capture_stdout do
        logger.log_task_complete(version: version, duration: duration)
      end
      complete_json = JSON.parse(complete_output.strip)
      assert_equal version, complete_json["version"]
      assert_equal duration, complete_json["duration_seconds"]
      assert_equal "completed", complete_json["status"]
      refute_nil complete_json["timestamp"]

      # Test task_failure
      error = StandardError.new(error_msg)
      error.set_backtrace(Array.new(5) { |i| "file.rb:#{i}:in `method_#{i}'" })
      failure_output = capture_stdout do
        logger.log_task_failure(version: version, error: error, phase: phase)
      end
      failure_json = JSON.parse(failure_output.strip)
      assert_equal version, failure_json["version"]
      assert_equal "StandardError", failure_json["error_class"]
      assert_equal error_msg, failure_json["error_message"]
      assert_kind_of Array, failure_json["backtrace"]
      refute_nil failure_json["timestamp"]
    }
  end

  # Feature: deployment-task-gem, Property 15: Dual log output
  # **Validates: Requirements 6.5**
  def test_dual_log_output
    property_of {
      version = sized(14) { string(:digit) }
      version = "0" * (14 - version.length) + version if version.length < 14
      description = sized(range(1, 30)) { string(:alpha) }
      phase = choose(:pre_deploy, :post_deploy)
      [version, description, phase]
    }.check(100) { |version, description, phase|
      execution_id = SecureRandom.uuid

      # Set up a StringIO-backed logger to capture configured logger output
      string_io = StringIO.new
      custom_logger = ::Logger.new(string_io)

      DeploymentTask.configure do |config|
        config.logger = custom_logger
      end

      logger = DeploymentTask::TaskLogger.new(execution_id: execution_id)

      stdout_output = capture_stdout do
        logger.log_task_start(version: version, description: description, phase: phase)
      end

      # Verify STDOUT received the entry
      stdout_json = JSON.parse(stdout_output.strip)
      assert_equal execution_id, stdout_json["execution_id"]

      # Verify configured logger also received the entry
      logger_output = string_io.string
      refute_empty logger_output, "Configured logger should have received the log entry"
      # The logger wraps the message, so we check the JSON is embedded in the output
      assert_includes logger_output, execution_id
    }
  end

  # Feature: deployment-task-gem, Property 16: Error reporter invocation on failure
  # **Validates: Requirements 6.6**
  def test_error_reporter_invocation_on_failure
    property_of {
      version = sized(14) { string(:digit) }
      version = "0" * (14 - version.length) + version if version.length < 14
      error_msg = sized(range(1, 30)) { string(:alpha) }
      phase = choose(:pre_deploy, :post_deploy)
      [version, error_msg, phase]
    }.check(100) { |version, error_msg, phase|
      execution_id = SecureRandom.uuid
      reported_args = nil

      DeploymentTask.configure do |config|
        config.error_reporter = ->(error, context) {
          reported_args = { error: error, context: context }
        }
      end

      logger = DeploymentTask::TaskLogger.new(execution_id: execution_id)
      error = RuntimeError.new(error_msg)
      error.set_backtrace(["test.rb:1:in `test'"])

      capture_stdout do
        logger.log_task_failure(version: version, error: error, phase: phase)
      end

      refute_nil reported_args, "Error reporter should have been called"
      assert_equal error, reported_args[:error]
      assert_equal version, reported_args[:context][:version]
      assert_equal phase, reported_args[:context][:phase]
      assert_equal execution_id, reported_args[:context][:execution_id]
    }
  end

  # --- Unit tests for TaskLogger (Task 5.6) ---
  # Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6

  def test_task_start_json_format
    logger = DeploymentTask::TaskLogger.new(execution_id: "test-uuid-123")

    output = capture_stdout do
      logger.log_task_start(version: "20250101120000", description: "Test task", phase: :post_deploy)
    end

    json = JSON.parse(output.strip)
    assert_equal "task_start", json["event"]
    assert_equal "20250101120000", json["version"]
    assert_equal "Test task", json["description"]
    assert_equal "post_deploy", json["phase"]
    assert_equal "test-uuid-123", json["execution_id"]
    refute_nil json["timestamp"]
  end

  def test_task_complete_json_format
    logger = DeploymentTask::TaskLogger.new(execution_id: "test-uuid-123")

    output = capture_stdout do
      logger.log_task_complete(version: "20250101120000", duration: 1.234)
    end

    json = JSON.parse(output.strip)
    assert_equal "task_complete", json["event"]
    assert_equal "20250101120000", json["version"]
    assert_equal 1.234, json["duration_seconds"]
    assert_equal "completed", json["status"]
    assert_equal "test-uuid-123", json["execution_id"]
    refute_nil json["timestamp"]
  end

  def test_task_failure_json_format
    logger = DeploymentTask::TaskLogger.new(execution_id: "test-uuid-123")
    error = RuntimeError.new("something broke")
    error.set_backtrace(Array.new(5) { |i| "file.rb:#{i}:in `method'" })

    output = capture_stdout do
      logger.log_task_failure(version: "20250101120000", error: error, phase: :pre_deploy)
    end

    json = JSON.parse(output.strip)
    assert_equal "task_failure", json["event"]
    assert_equal "20250101120000", json["version"]
    assert_equal "failed", json["status"]
    assert_equal "RuntimeError", json["error_class"]
    assert_equal "something broke", json["error_message"]
    assert_kind_of Array, json["backtrace"]
    assert_equal 5, json["backtrace"].length
    assert_equal "test-uuid-123", json["execution_id"]
    refute_nil json["timestamp"]
  end

  def test_backtrace_limited_to_20_lines
    logger = DeploymentTask::TaskLogger.new(execution_id: "test-uuid-123")
    error = RuntimeError.new("deep error")
    error.set_backtrace(Array.new(50) { |i| "file.rb:#{i}:in `method'" })

    output = capture_stdout do
      logger.log_task_failure(version: "20250101120000", error: error, phase: :pre_deploy)
    end

    json = JSON.parse(output.strip)
    assert_equal 20, json["backtrace"].length
  end

  def test_error_reporter_failure_is_silently_rescued
    DeploymentTask.configure do |config|
      config.error_reporter = ->(error, context) {
        raise "Reporter exploded!"
      }
    end

    logger = DeploymentTask::TaskLogger.new(execution_id: "test-uuid-123")
    error = RuntimeError.new("task error")
    error.set_backtrace(["test.rb:1:in `test'"])

    # Should not raise even though error_reporter raises
    output = capture_stdout do
      logger.log_task_failure(version: "20250101120000", error: error, phase: :pre_deploy)
    end

    json = JSON.parse(output.strip)
    assert_equal "task_failure", json["event"]
  end

  def test_task_skip_json_format
    logger = DeploymentTask::TaskLogger.new(execution_id: "test-uuid-123")

    output = capture_stdout do
      logger.log_task_skip(version: "20250101120000", description: "Already done")
    end

    json = JSON.parse(output.strip)
    assert_equal "task_skip", json["event"]
    assert_equal "20250101120000", json["version"]
    assert_equal "Already done", json["description"]
    assert_equal "skipped", json["status"]
    assert_equal "test-uuid-123", json["execution_id"]
  end

  private

  def capture_stdout
    old_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old_stdout
  end

  def property_of(&block)
    Rantly::Property.new(block)
  end
end
