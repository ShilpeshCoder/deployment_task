# frozen_string_literal: true

require_relative "../test_helper"
require "rantly"
require "rantly/property"

class RecordTest < Minitest::Test
  include TaskTestHelper

  # ============================================================================
  # Task 4.3 — Property 20: AASM state transitions set correct fields
  # Feature: deployment-task-gem, Property 20: AASM state transitions set correct fields
  # **Validates: Requirements 9.3, 9.4, 9.5**
  # ============================================================================
  def test_aasm_state_transitions_set_correct_fields_property
    property_of {
      offset = integer(1..100_000)
      offset
    }.check(100) { |offset|
      version = generate_version(offset)

      # --- start! sets started_at (pending → running) ---
      record = DeploymentTask::Record.create!(
        version: version,
        phase: "post_deploy",
        task_name: "test_task",
        status: "pending"
      )

      assert record.pending?
      record.start!
      record.reload

      assert record.running?
      refute_nil record.started_at, "start! should set started_at"

      # --- complete! sets completed_at and execution_time_seconds (running → completed) ---
      record.complete!
      record.reload

      assert record.completed?
      refute_nil record.completed_at, "complete! should set completed_at"
      refute_nil record.execution_time_seconds, "complete! should set execution_time_seconds"
      assert record.completed_at >= record.started_at,
        "completed_at should be >= started_at"

      # Clean up for next iteration
      record.destroy!

      # --- fail! sets completed_at (running → failed) ---
      fail_version = generate_version(offset + 100_001)
      fail_record = DeploymentTask::Record.create!(
        version: fail_version,
        phase: "pre_deploy",
        task_name: "fail_task",
        status: "pending"
      )

      fail_record.start!
      fail_record.reload
      refute_nil fail_record.started_at

      fail_record.fail!
      fail_record.reload

      assert fail_record.failed?
      refute_nil fail_record.completed_at, "fail! should set completed_at"

      fail_record.destroy!
    }
  end

  # ============================================================================
  # Task 4.4 — Property 12: Unique version constraint
  # Feature: deployment-task-gem, Property 12: Unique version constraint
  # **Validates: Requirements 5.4**
  # ============================================================================
  def test_unique_version_constraint_property
    property_of {
      # Generate a random 14-digit version string
      sized(14) { string(:digit) }
    }.check(100) { |version|
      # Ensure we start clean for this version
      DeploymentTask::Record.where(version: version).delete_all

      # Create the first record — should succeed
      DeploymentTask::Record.create!(
        version: version,
        phase: "post_deploy",
        task_name: "first_task"
      )

      # Attempt to create a duplicate — should raise
      assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique) do
        DeploymentTask::Record.create!(
          version: version,
          phase: "post_deploy",
          task_name: "duplicate_task"
        )
      end

      # Clean up
      DeploymentTask::Record.where(version: version).delete_all
    }
  end

  # ============================================================================
  # Task 4.5 — Unit tests for Record model
  # Requirements: 9.1, 9.3, 9.4, 9.5, 9.6
  # ============================================================================

  # --- Valid AASM transitions ---

  def test_transition_pending_to_running
    record = create_record("20250101000001")
    assert record.pending?
    record.start!
    assert record.running?
  end

  def test_transition_running_to_completed
    record = create_record("20250101000002")
    record.start!
    record.complete!
    assert record.completed?
  end

  def test_transition_running_to_failed
    record = create_record("20250101000003")
    record.start!
    record.fail!
    assert record.failed?
  end

  def test_transition_pending_to_skipped
    record = create_record("20250101000004")
    record.skip!
    assert record.skipped?
  end

  def test_transition_failed_to_pending
    record = create_record("20250101000005")
    record.start!
    record.fail!
    assert record.failed?
    record.reset!
    assert record.pending?
  end

  # --- Invalid AASM transitions ---

  def test_invalid_transition_pending_to_completed
    record = create_record("20250101000010")
    assert_raises(AASM::InvalidTransition) { record.complete! }
  end

  def test_invalid_transition_completed_to_running
    record = create_record("20250101000011")
    record.start!
    record.complete!
    assert_raises(AASM::InvalidTransition) { record.start! }
  end

  def test_invalid_transition_pending_to_failed
    record = create_record("20250101000012")
    assert_raises(AASM::InvalidTransition) { record.fail! }
  end

  def test_invalid_transition_skipped_to_running
    record = create_record("20250101000013")
    record.skip!
    assert_raises(AASM::InvalidTransition) { record.start! }
  end

  # --- Validations ---

  def test_validation_missing_version
    record = DeploymentTask::Record.new(
      phase: "post_deploy",
      task_name: "some_task"
    )
    refute record.valid?
    assert record.errors[:version].any?
  end

  def test_validation_invalid_phase
    record = DeploymentTask::Record.new(
      version: "20250101000020",
      phase: "invalid_phase",
      task_name: "some_task"
    )
    refute record.valid?
    assert record.errors[:phase].any?
  end

  def test_validation_missing_task_name
    record = DeploymentTask::Record.new(
      version: "20250101000021",
      phase: "post_deploy"
    )
    refute record.valid?
    assert record.errors[:task_name].any?
  end

  def test_validation_missing_phase
    record = DeploymentTask::Record.new(
      version: "20250101000022",
      task_name: "some_task"
    )
    refute record.valid?
    assert record.errors[:phase].any?
  end

  # --- Scopes ---

  def test_scope_for_phase
    DeploymentTask::Record.create!(version: "20250101000030", phase: "pre_deploy", task_name: "pre_task")
    DeploymentTask::Record.create!(version: "20250101000031", phase: "post_deploy", task_name: "post_task")

    pre_records = DeploymentTask::Record.for_phase("pre_deploy")
    post_records = DeploymentTask::Record.for_phase("post_deploy")

    assert_equal 1, pre_records.count
    assert_equal "pre_task", pre_records.first.task_name

    assert_equal 1, post_records.count
    assert_equal "post_task", post_records.first.task_name
  end

  def test_scope_failed_tasks
    r1 = create_record("20250101000040")
    r2 = create_record("20250101000041")
    r3 = create_record("20250101000042")

    # Make r1 failed
    r1.start!
    r1.fail!

    # Make r2 completed
    r2.start!
    r2.complete!

    # r3 stays pending

    failed = DeploymentTask::Record.failed_tasks
    assert_equal 1, failed.count
    assert_equal r1.id, failed.first.id
  end

  private

  def create_record(version, phase: "post_deploy", task_name: "test_task")
    DeploymentTask::Record.create!(
      version: version,
      phase: phase,
      task_name: task_name
    )
  end

  def property_of(&block)
    Rantly::Property.new(block)
  end
end
