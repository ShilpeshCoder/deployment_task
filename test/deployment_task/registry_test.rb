# frozen_string_literal: true

require_relative "../test_helper"
require "rantly"
require "rantly/property"

class RegistryTest < Minitest::Test
  include TaskTestHelper

  # Feature: deployment-task-gem, Property 2: Self-registration on inheritance
  # **Validates: Requirements 3.1**
  def test_self_registration_on_inheritance_property
    property_of {
      count = range(1, 5)
      versions = []
      count.times do |i|
        # Generate unique valid 14-digit versions
        ts = integer(20200101000000..20291231235959).to_s
        # Ensure uniqueness by appending index offset
        versions << (ts.to_i + i).to_s
      end
      phase = choose(:pre_deploy, :post_deploy)
      [versions.uniq, phase]
    }.check(100) { |versions, phase|
      DeploymentTask.reset!

      created_classes = versions.map do |v|
        create_task_class(version: v, phase: phase, description: "Task #{v}")
      end

      all = DeploymentTask::Registry.all_tasks
      assert_equal versions.size, all.size,
        "Expected #{versions.size} tasks in registry, got #{all.size}"

      registered_classes = all.map { |entry| entry[:task_class] }
      created_classes.each do |klass|
        assert_includes registered_classes, klass,
          "Expected registry to contain the created task class"
      end
    }
  end

  # Feature: deployment-task-gem, Property 3: Registry rejects invalid metadata
  # **Validates: Requirements 3.2, 3.4**
  def test_registry_rejects_invalid_metadata_property
    property_of {
      invalid_version = choose(
        nil,
        "",
        # Short string (1-13 digits)
        sized(range(1, 13)) { string(:digit) },
        # Alpha string
        sized(range(1, 20)) { string(:alpha) }
      )
      invalid_version
    }.check(100) { |invalid_version|
      DeploymentTask.reset!

      create_task_class(
        version: invalid_version.to_s,
        phase: :post_deploy,
        description: "Invalid task"
      )

      assert_raises(DeploymentTask::InvalidVersionError) do
        DeploymentTask::Registry.tasks_for_phase(:post_deploy)
      end
    }
  end

  # Feature: deployment-task-gem, Property 4: Duplicate version detection
  # **Validates: Requirements 3.5**
  def test_duplicate_version_detection_property
    property_of {
      integer(20200101000000..20291231235959).to_s
    }.check(100) { |version|
      DeploymentTask.reset!

      create_task_class(version: version, phase: :post_deploy, description: "First task")
      create_task_class(version: version, phase: :post_deploy, description: "Duplicate task")

      assert_raises(DeploymentTask::DuplicateVersionError) do
        DeploymentTask::Registry.tasks_for_phase(:post_deploy)
      end
    }
  end

  # Feature: deployment-task-gem, Property 5: Version-ordered execution
  # **Validates: Requirements 3.6, 4.1, 4.2**
  def test_version_ordered_execution_property
    property_of {
      count = range(2, 8)
      versions = []
      count.times do
        versions << integer(20200101000000..20291231235959).to_s
      end
      phase = choose(:pre_deploy, :post_deploy)
      [versions.uniq, phase]
    }.check(100) { |versions, phase|
      next if versions.size < 2

      DeploymentTask.reset!

      versions.each do |v|
        create_task_class(version: v, phase: phase, description: "Task #{v}")
      end

      result = DeploymentTask::Registry.tasks_for_phase(phase)
      result_versions = result.map(&:task_version)

      assert_equal result_versions, result_versions.sort,
        "Expected tasks to be sorted ascending by version, got: #{result_versions.inspect}"
    }
  end

  # --- Unit tests for Registry (Task 2.7) ---
  # Requirements: 3.2, 3.4, 3.5

  def test_invalid_version_nil
    create_task_class(version: nil.to_s, phase: :post_deploy)
    assert_raises(DeploymentTask::InvalidVersionError) do
      DeploymentTask::Registry.tasks_for_phase(:post_deploy)
    end
  end

  def test_invalid_version_empty
    create_task_class(version: "", phase: :post_deploy)
    assert_raises(DeploymentTask::InvalidVersionError) do
      DeploymentTask::Registry.tasks_for_phase(:post_deploy)
    end
  end

  def test_invalid_version_13_digits
    create_task_class(version: "2025010112000", phase: :post_deploy)
    assert_raises(DeploymentTask::InvalidVersionError) do
      DeploymentTask::Registry.tasks_for_phase(:post_deploy)
    end
  end

  def test_invalid_version_alpha_string
    create_task_class(version: "abcdefghijklmn", phase: :post_deploy)
    assert_raises(DeploymentTask::InvalidVersionError) do
      DeploymentTask::Registry.tasks_for_phase(:post_deploy)
    end
  end

  def test_duplicate_version_with_named_classes
    version = "20250601120000"

    klass_a = create_task_class(version: version, phase: :post_deploy, description: "Task A")
    klass_b = create_task_class(version: version, phase: :pre_deploy, description: "Task B")

    error = assert_raises(DeploymentTask::DuplicateVersionError) do
      DeploymentTask::Registry.all_tasks
    end

    assert_match(/Duplicate version/, error.message)
    assert_match(version, error.message)
  end

  private

  def property_of(&block)
    Rantly::Property.new(block)
  end
end
