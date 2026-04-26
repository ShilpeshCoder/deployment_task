# frozen_string_literal: true

require "json"
require "time"

module DeploymentTask
  class TaskLogger
    attr_reader :execution_id

    def initialize(execution_id:)
      @execution_id = execution_id
    end

    def log_task_start(version:, description:, phase:)
      log(event: "task_start", version: version, description: description,
          phase: phase, timestamp: Time.now.utc.iso8601)
    end

    def log_task_complete(version:, duration:)
      log(event: "task_complete", version: version,
          duration_seconds: duration, status: "completed",
          timestamp: Time.now.utc.iso8601)
    end

    def log_task_failure(version:, error:, phase:)
      payload = {
        event: "task_failure", version: version, status: "failed",
        error_class: error.class.name, error_message: error.message,
        backtrace: error.backtrace&.first(20),
        timestamp: Time.now.utc.iso8601
      }
      log(payload)
      report_error(error, version: version, phase: phase)
    end

    def log_task_skip(version:, description:)
      log(event: "task_skip", version: version, description: description,
          status: "skipped", timestamp: Time.now.utc.iso8601)
    end

    def log_phase_start(phase:, task_count:, dry_run:)
      log(event: "phase_start", phase: phase, task_count: task_count,
          dry_run: dry_run, timestamp: Time.now.utc.iso8601)
    end

    def log_phase_summary(phase:, results:)
      log(event: "phase_summary", phase: phase, **results,
          timestamp: Time.now.utc.iso8601)
    end

    def log_dry_run_entry(version:, description:, phase:, status:)
      log(event: "dry_run_entry", version: version, description: description,
          phase: phase, current_status: status, timestamp: Time.now.utc.iso8601)
    end

    private

    def log(payload)
      entry = payload.merge(execution_id: execution_id).to_json
      $stdout.puts(entry)
      configured_logger&.info(entry)
    end

    def configured_logger
      DeploymentTask.configuration.logger
    end

    def report_error(error, version:, phase:)
      reporter = DeploymentTask.configuration.error_reporter
      context = { version: version, phase: phase, execution_id: execution_id }
      reporter.call(error, context)
    rescue StandardError
      # Silently ignore error reporter failures — logging already captured the error
    end
  end
end
