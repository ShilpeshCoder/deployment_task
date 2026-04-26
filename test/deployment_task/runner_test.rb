# frozen_string_literal: true

require_relative "../test_helper"
require "rantly"
require "rantly/property"
require "stringio"
require "json"

class RunnerTest < Minitest::Test
  include TaskTestHelper

  # Helper: create a task class with a guaranteed non-nil task_name.
  # Anonymous classes return nil for task_name, so we define a task_name override.
  def create_runner_task(version:, phase: :post_deploy, description: "Test task", &block)
    task_name = "task_#{version}"
    klass = Class.new(DeploymentTask::Base) do
      self.version(version)
      self.phase(phase)
      self.description(description)

      define_singleton_method(:task_name) { task_name }

      if block
        define_method(:execute, &block)
      else
        define_method(:execute) { }
      end
    end
    klass
  end

  # ===========================================================================
  # Task 8.2 — Property 6: Sequential execution timing
  # Feature: deployment-task-gem, Property 6: Sequential execution timing
  # **Validates: Requirements 4.3**
  # ===========================================================================
  def test_sequential_execution_timing_property
    iteration = 0
    property_of {
      count = range(2, 5)
      count
    }.check(100) { |count|
      DeploymentTask.reset!
      DeploymentTask.configure do |config|
        config.lock_adapter = :none
        config.logger = nil
      end

      base = iteration * 10
      iteration += 1
      versions = (0...count).map { |i| generate_version(base + i) }
      versions.each do |v|
        create_runner_task(version: v, phase: :post_deploy, description: "Task #{v}")
      end

      capture_stdout do
        DeploymentTask::Runner.new(phase: :post_deploy).run
      end

      records = versions.map { |v| DeploymentTask::Record.find_by!(version: v) }

      records.each_cons(2) do |prev_record, next_record|
        assert next_record.started_at >= prev_record.completed_at,
          "Task #{next_record.version} started_at (#{next_record.started_at}) " \
          "should be >= previous task #{prev_record.version} completed_at (#{prev_record.completed_at})"
      end
    }
  end

  # ===========================================================================
  # Task 8.3 — Property 7: Halt on failure
  # Feature: deployment-task-gem, Property 7: Halt on failure
  # **Validates: Requirements 4.4**
  # ===========================================================================
  def test_halt_on_failure_property
    iteration = 0
    property_of {
      count = range(3, 6)
      fail_at = range(0, count - 2)
      [count, fail_at]
    }.check(100) { |count, fail_at|
      DeploymentTask.reset!
      DeploymentTask.configure do |config|
        config.lock_adapter = :none
        config.logger = nil
      end

      base = iteration * 10
      iteration += 1
      versions = (0...count).map { |i| generate_version(base + i) }

      versions.each_with_index do |v, i|
        if i == fail_at
          create_runner_task(version: v, phase: :post_deploy, description: "Failing task") { raise "boom" }
        else
          create_runner_task(version: v, phase: :post_deploy, description: "Good task")
        end
      end

      capture_stdout do
        DeploymentTask::Runner.new(phase: :post_deploy).run
      end

      failed_record = DeploymentTask::Record.find_by(version: versions[fail_at])
      assert_equal "failed", failed_record.status,
        "Task at position #{fail_at} should be failed"

      versions[(fail_at + 1)..].each do |v|
        record = DeploymentTask::Record.find_by(version: v)
        assert_nil record,
          "Task #{v} after failure position should not have a record created"
      end
    }
  end

  # ===========================================================================
  # Task 8.4 — Property 8: Successful completion record integrity
  # Feature: deployment-task-gem, Property 8: Successful completion record integrity
  # **Validates: Requirements 4.5, 5.1**
  # ===========================================================================
  def test_successful_completion_record_integrity_property
    iteration = 0
    property_of {
      count = range(1, 4)
      count
    }.check(100) { |count|
      DeploymentTask.reset!
      DeploymentTask.configure do |config|
        config.lock_adapter = :none
        config.logger = nil
      end

      phase = :post_deploy
      base = iteration * 10
      iteration += 1
      versions = (0...count).map { |i| generate_version(base + i) }

      versions.each do |v|
        create_runner_task(version: v, phase: phase, description: "Task #{v}")
      end

      runner = DeploymentTask::Runner.new(phase: phase)
      execution_id = runner.execution_id

      capture_stdout { runner.run }

      versions.each do |v|
        record = DeploymentTask::Record.find_by!(version: v)

        assert_equal "completed", record.status
        refute_nil record.started_at
        refute_nil record.completed_at
        assert record.completed_at >= record.started_at,
          "completed_at should be >= started_at for #{v}"
        refute_nil record.execution_time_seconds
        assert_equal v, record.version
        assert_equal phase.to_s, record.phase
        assert_equal execution_id, record.execution_id
      end
    }
  end

  # ===========================================================================
  # Task 8.5 — Property 9: Summary count invariant
  # Feature: deployment-task-gem, Property 9: Summary count invariant
  # **Validates: Requirements 4.6**
  # ===========================================================================
  def test_summary_count_invariant_property
    iteration = 0
    property_of {
      count = range(2, 5)
      fail_at = range(0, count) # count means no failure
      skip_count = range(0, [count - 1, 1].min)
      [count, fail_at, skip_count]
    }.check(100) { |count, fail_at, skip_count|
      DeploymentTask.reset!
      DeploymentTask.configure do |config|
        config.lock_adapter = :none
        config.logger = nil
      end

      base = iteration * 10
      iteration += 1
      versions = (0...count).map { |i| generate_version(base + i) }

      # Pre-create completed records for the first skip_count tasks
      versions.first(skip_count).each do |v|
        r = DeploymentTask::Record.create!(
          version: v, phase: "post_deploy", task_name: "task_#{v}",
          status: "pending"
        )
        r.start!
        r.complete!
      end

      versions.each_with_index do |v, i|
        if i >= skip_count && i == fail_at
          create_runner_task(version: v, phase: :post_deploy, description: "Failing") { raise "boom" }
        else
          create_runner_task(version: v, phase: :post_deploy, description: "Good")
        end
      end

      output = capture_stdout do
        DeploymentTask::Runner.new(phase: :post_deploy).run
      end

      summary_line = output.lines.find { |l| l.include?('"phase_summary"') }
      refute_nil summary_line, "Should have a phase_summary log line"

      summary = JSON.parse(summary_line.strip)
      total = summary["total"]
      succeeded = summary["succeeded"]
      failed = summary["failed"]
      skipped = summary["skipped"]

      assert_equal total, succeeded + failed + skipped,
        "total (#{total}) should equal succeeded (#{succeeded}) + failed (#{failed}) + skipped (#{skipped})"
    }
  end

  # ===========================================================================
  # Task 8.6 — Property 10: Idempotent skip of completed tasks
  # Feature: deployment-task-gem, Property 10: Idempotent skip of completed tasks
  # **Validates: Requirements 5.2**
  # ===========================================================================
  def test_idempotent_skip_of_completed_tasks_property
    iteration = 0
    property_of {
      count = range(1, 4)
      count
    }.check(100) { |count|
      DeploymentTask.reset!
      DeploymentTask.configure do |config|
        config.lock_adapter = :none
        config.logger = nil
      end

      base = iteration * 10
      iteration += 1
      versions = (0...count).map { |i| generate_version(base + i) }

      # Pre-create completed records
      versions.each do |v|
        r = DeploymentTask::Record.create!(
          version: v, phase: "post_deploy", task_name: "task_#{v}",
          description: "Task #{v}", status: "pending"
        )
        r.start!
        r.complete!
      end

      before_snapshots = versions.map do |v|
        record = DeploymentTask::Record.find_by!(version: v)
        { status: record.status, started_at: record.started_at,
          completed_at: record.completed_at, execution_time_seconds: record.execution_time_seconds }
      end

      executed = []
      versions.each do |v|
        create_runner_task(version: v, phase: :post_deploy, description: "Task #{v}") {
          executed << v
        }
      end

      capture_stdout do
        DeploymentTask::Runner.new(phase: :post_deploy).run
      end

      assert_empty executed, "No tasks should have been executed since all are completed"

      versions.each_with_index do |v, i|
        record = DeploymentTask::Record.find_by!(version: v)
        assert_equal "completed", record.status
        assert_equal before_snapshots[i][:started_at].to_i, record.started_at.to_i
        assert_equal before_snapshots[i][:completed_at].to_i, record.completed_at.to_i
      end
    }
  end

  # ===========================================================================
  # Task 8.7 — Property 11: Re-attempt of failed tasks
  # Feature: deployment-task-gem, Property 11: Re-attempt of failed tasks
  # **Validates: Requirements 5.3**
  # ===========================================================================
  def test_re_attempt_of_failed_tasks_property
    iteration = 0
    property_of {
      count = range(1, 4)
      count
    }.check(100) { |count|
      DeploymentTask.reset!
      DeploymentTask.configure do |config|
        config.lock_adapter = :none
        config.logger = nil
      end

      base = iteration * 10
      iteration += 1
      versions = (0...count).map { |i| generate_version(base + i) }

      # Pre-create failed records
      versions.each do |v|
        r = DeploymentTask::Record.create!(
          version: v, phase: "post_deploy", task_name: "task_#{v}",
          description: "Task #{v}", status: "pending"
        )
        r.start!
        r.fail!
        r.update!(error_message: "previous failure", error_class: "RuntimeError")
      end

      # Register matching tasks that now succeed
      versions.each do |v|
        create_runner_task(version: v, phase: :post_deploy, description: "Task #{v}")
      end

      capture_stdout do
        DeploymentTask::Runner.new(phase: :post_deploy).run
      end

      versions.each do |v|
        record = DeploymentTask::Record.find_by!(version: v)
        assert_equal "completed", record.status,
          "Failed task #{v} should now be completed after re-attempt"
      end
    }
  end

  # ===========================================================================
  # Task 8.8 — Property 17: Runner return value reflects success/failure
  # Feature: deployment-task-gem, Property 17: Runner return value reflects success/failure
  # **Validates: Requirements 7.3, 7.4**
  # ===========================================================================
  def test_runner_return_value_reflects_success_failure_property
    iteration = 0
    property_of {
      count = range(1, 5)
      has_failure = choose(true, false)
      [count, has_failure]
    }.check(100) { |count, has_failure|
      DeploymentTask.reset!
      DeploymentTask.configure do |config|
        config.lock_adapter = :none
        config.logger = nil
      end

      base = iteration * 10
      iteration += 1
      versions = (0...count).map { |i| generate_version(base + i) }
      fail_at = has_failure ? rand(count) : nil

      versions.each_with_index do |v, i|
        if i == fail_at
          create_runner_task(version: v, phase: :post_deploy, description: "Failing") { raise "boom" }
        else
          create_runner_task(version: v, phase: :post_deploy, description: "Good")
        end
      end

      result = nil
      capture_stdout do
        result = DeploymentTask::Runner.new(phase: :post_deploy).run
      end

      if has_failure
        assert_equal false, result, "Runner should return false when a task fails"
      else
        assert_equal true, result, "Runner should return true when all tasks succeed"
      end
    }
  end

  # ===========================================================================
  # Task 8.9 — Property 21: Dry run does not modify records or execute tasks
  # Feature: deployment-task-gem, Property 21: Dry run does not modify records or execute tasks
  # **Validates: Requirements 10.1, 10.3**
  # ===========================================================================
  def test_dry_run_does_not_modify_records_or_execute_tasks_property
    iteration = 0
    property_of {
      count = range(1, 4)
      count
    }.check(100) { |count|
      DeploymentTask.reset!
      DeploymentTask.configure do |config|
        config.lock_adapter = :none
        config.logger = nil
      end

      base = iteration * 10
      iteration += 1
      versions = (0...count).map { |i| generate_version(base + i) }
      executed = []

      versions.each do |v|
        create_runner_task(version: v, phase: :post_deploy, description: "Task #{v}") {
          executed << v
        }
      end

      record_count_before = DeploymentTask::Record.count

      capture_stdout do
        DeploymentTask::Runner.new(phase: :post_deploy, dry_run: true).run
      end

      record_count_after = DeploymentTask::Record.count

      assert_empty executed, "No tasks should have been executed in dry run mode"
      assert_equal record_count_before, record_count_after,
        "No records should have been created or modified in dry run mode"
    }
  end

  # ===========================================================================
  # Task 8.10 — Property 22: Dry run output contains required fields
  # Feature: deployment-task-gem, Property 22: Dry run output contains required fields
  # **Validates: Requirements 10.2**
  # ===========================================================================
  def test_dry_run_output_contains_required_fields_property
    iteration = 0
    property_of {
      count = range(1, 4)
      count
    }.check(100) { |count|
      DeploymentTask.reset!
      DeploymentTask.configure do |config|
        config.lock_adapter = :none
        config.logger = nil
      end

      phase = :post_deploy
      base = iteration * 10
      iteration += 1
      versions = (0...count).map { |i| generate_version(base + i) }
      descriptions = versions.map { |v| "Desc for #{v}" }

      versions.each_with_index do |v, i|
        create_runner_task(version: v, phase: phase, description: descriptions[i])
      end

      output = capture_stdout do
        DeploymentTask::Runner.new(phase: phase, dry_run: true).run
      end

      dry_run_lines = output.lines.select { |l| l.include?('"dry_run_entry"') }
      assert_equal count, dry_run_lines.size,
        "Expected #{count} dry_run_entry lines, got #{dry_run_lines.size}"

      dry_run_lines.each_with_index do |line, i|
        entry = JSON.parse(line.strip)
        assert_equal versions[i], entry["version"]
        assert_equal descriptions[i], entry["description"]
        assert_equal phase.to_s, entry["phase"]
        refute_nil entry["current_status"]
      end
    }
  end

  # ===========================================================================
  # Task 8.11 — Unit tests for Runner
  # Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 5.1, 5.2, 5.3, 10.1
  # ===========================================================================

  def test_successful_execution_of_multiple_tasks_in_order
    execution_order = []

    v1 = generate_version(0)
    v2 = generate_version(1)
    v3 = generate_version(2)

    create_runner_task(version: v1, phase: :post_deploy, description: "First") {
      execution_order << v1
    }
    create_runner_task(version: v2, phase: :post_deploy, description: "Second") {
      execution_order << v2
    }
    create_runner_task(version: v3, phase: :post_deploy, description: "Third") {
      execution_order << v3
    }

    result = nil
    capture_stdout do
      result = DeploymentTask::Runner.new(phase: :post_deploy).run
    end

    assert_equal true, result
    assert_equal [v1, v2, v3], execution_order, "Tasks should execute in version order"
    assert_equal 3, DeploymentTask::Record.where(status: "completed").count
  end

  def test_skip_of_completed_tasks
    v1 = generate_version(0)
    v2 = generate_version(1)

    # Pre-create a completed record for v1
    r = DeploymentTask::Record.create!(
      version: v1, phase: "post_deploy", task_name: "task_#{v1}", status: "pending"
    )
    r.start!
    r.complete!

    executed = []
    create_runner_task(version: v1, phase: :post_deploy, description: "Should skip") {
      executed << v1
    }
    create_runner_task(version: v2, phase: :post_deploy, description: "Should run") {
      executed << v2
    }

    capture_stdout do
      DeploymentTask::Runner.new(phase: :post_deploy).run
    end

    assert_equal [v2], executed, "Only v2 should have been executed"
  end

  def test_retry_of_failed_tasks
    v1 = generate_version(0)

    r = DeploymentTask::Record.create!(
      version: v1, phase: "post_deploy", task_name: "task_#{v1}", status: "pending"
    )
    r.start!
    r.fail!
    r.update!(error_message: "old error", error_class: "RuntimeError")

    create_runner_task(version: v1, phase: :post_deploy, description: "Retry task")

    capture_stdout do
      DeploymentTask::Runner.new(phase: :post_deploy).run
    end

    record = DeploymentTask::Record.find_by!(version: v1)
    assert_equal "completed", record.status
  end

  def test_halt_on_failure_stops_remaining_tasks
    v1 = generate_version(0)
    v2 = generate_version(1)
    v3 = generate_version(2)

    executed = []
    create_runner_task(version: v1, phase: :post_deploy, description: "OK") {
      executed << v1
    }
    create_runner_task(version: v2, phase: :post_deploy, description: "Fail") { raise "boom" }
    create_runner_task(version: v3, phase: :post_deploy, description: "Never") {
      executed << v3
    }

    result = nil
    capture_stdout do
      result = DeploymentTask::Runner.new(phase: :post_deploy).run
    end

    assert_equal false, result
    assert_equal [v1], executed, "Only v1 should have executed before halt"
    assert_nil DeploymentTask::Record.find_by(version: v3),
      "v3 should not have a record since execution halted"
  end

  def test_dry_run_mode
    v1 = generate_version(0)
    v2 = generate_version(1)

    executed = []
    create_runner_task(version: v1, phase: :post_deploy, description: "Task 1") {
      executed << v1
    }
    create_runner_task(version: v2, phase: :post_deploy, description: "Task 2") {
      executed << v2
    }

    record_count_before = DeploymentTask::Record.count

    output = capture_stdout do
      DeploymentTask::Runner.new(phase: :post_deploy, dry_run: true).run
    end

    assert_empty executed, "No tasks should execute in dry run"
    assert_equal record_count_before, DeploymentTask::Record.count
    dry_entries = output.lines.select { |l| l.include?('"dry_run_entry"') }
    assert_equal 2, dry_entries.size
  end

  def test_find_or_create_record_creates_with_correct_attributes
    v1 = generate_version(0)
    create_runner_task(version: v1, phase: :post_deploy, description: "My task")

    capture_stdout do
      DeploymentTask::Runner.new(phase: :post_deploy).run
    end

    record = DeploymentTask::Record.find_by!(version: v1)
    assert_equal "post_deploy", record.phase
    assert_equal "My task", record.description
    refute_nil record.execution_id
  end

  def test_error_handling_sets_error_message_and_error_class
    v1 = generate_version(0)
    create_runner_task(version: v1, phase: :post_deploy, description: "Boom task") {
      raise ArgumentError, "bad argument"
    }

    capture_stdout do
      DeploymentTask::Runner.new(phase: :post_deploy).run
    end

    record = DeploymentTask::Record.find_by!(version: v1)
    assert_equal "failed", record.status
    assert_equal "bad argument", record.error_message
    assert_equal "ArgumentError", record.error_class
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
