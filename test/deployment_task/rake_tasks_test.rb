# frozen_string_literal: true

require_relative "../test_helper"
require "rake"

# Load the rake file and define the :environment prerequisite task
# so that the deploy:* tasks can be resolved.
Rake::Task.define_task(:environment)
Rake::DefaultLoader.new.load(
  File.expand_path("../../lib/tasks/deploy.rake", __dir__)
)

class RakeTasksTest < Minitest::Test
  # Validates: Requirements 7.1
  def test_deploy_pre_task_is_defined
    assert Rake::Task.task_defined?("deploy:pre"),
      "Expected deploy:pre rake task to be defined"
  end

  # Validates: Requirements 7.2
  def test_deploy_post_task_is_defined
    assert Rake::Task.task_defined?("deploy:post"),
      "Expected deploy:post rake task to be defined"
  end

  # Validates: Requirements 7.5
  def test_deploy_status_task_is_defined
    assert Rake::Task.task_defined?("deploy:status"),
      "Expected deploy:status rake task to be defined"
  end

  # Validates: Requirements 7.6
  def test_deploy_retry_failed_task_is_defined
    assert Rake::Task.task_defined?("deploy:retry_failed"),
      "Expected deploy:retry_failed rake task to be defined"
  end

  # Validates: Requirements 7.7
  def test_deploy_retry_failed_aborts_when_phase_is_missing
    # Ensure PHASE is not set
    ENV.delete("PHASE")

    # Re-enable the task so it can be invoked again
    Rake::Task["deploy:retry_failed"].reenable

    assert_raises(SystemExit) do
      # Capture stderr to suppress the abort message during test output
      _stderr = $stderr
      $stderr = StringIO.new
      begin
        Rake::Task["deploy:retry_failed"].invoke
      ensure
        $stderr = _stderr
      end
    end
  end
end
