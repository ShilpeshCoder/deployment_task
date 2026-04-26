# frozen_string_literal: true

require "securerandom"

module DeploymentTask
  class Runner
    attr_reader :phase, :execution_id, :dry_run

    def initialize(phase:, dry_run: false)
      @phase = phase.to_sym
      @execution_id = SecureRandom.uuid
      @dry_run = dry_run
      @results = { total: 0, succeeded: 0, failed: 0, skipped: 0 }
    end

    def run
      task_classes = Registry.tasks_for_phase(phase)
      logger = DeploymentTask::TaskLogger.new(execution_id: execution_id)

      logger.log_phase_start(phase: phase, task_count: task_classes.size, dry_run: dry_run)

      if dry_run
        run_dry(task_classes, logger)
      else
        run_live(task_classes, logger)
      end

      logger.log_phase_summary(phase: phase, results: @results)
      @results[:failed].zero?
    end

    private

    def run_dry(task_classes, logger)
      task_classes.each do |task_class|
        @results[:total] += 1
        record = DeploymentTask::Record.find_by(version: task_class.task_version)
        status = record&.status || "pending"
        logger.log_dry_run_entry(
          version: task_class.task_version,
          description: task_class.task_description,
          phase: phase,
          status: status
        )
      end
    end

    def run_live(task_classes, logger)
      task_classes.each do |task_class|
        @results[:total] += 1
        success = execute_task(task_class, logger)
        break unless success
      end
    end

    def execute_task(task_class, logger)
      record = find_or_create_record(task_class)

      if record.completed?
        @results[:skipped] += 1
        logger.log_task_skip(version: task_class.task_version,
                             description: task_class.task_description)
        return true
      end

      record.reset! if record.failed?

      lock_adapter.with_lock(task_class.task_version) do
        run_single_task(task_class, record, logger)
      end
    end

    def run_single_task(task_class, record, logger)
      record.start!
      record.update!(execution_id: execution_id)
      logger.log_task_start(version: task_class.task_version,
                            description: task_class.task_description,
                            phase: phase)

      task_class.new.execute

      record.complete!
      @results[:succeeded] += 1
      logger.log_task_complete(version: task_class.task_version,
                               duration: record.execution_time_seconds)
      true
    rescue StandardError => e
      handle_task_failure(task_class, record, logger, e)
      false
    end

    def find_or_create_record(task_class)
      DeploymentTask::Record.find_or_create_by!(version: task_class.task_version) do |r|
        r.phase = phase.to_s
        r.task_name = task_class.task_name
        r.description = task_class.task_description
        r.execution_id = execution_id
      end
    end

    def handle_task_failure(task_class, record, logger, error)
      record.fail!
      record.update!(
        error_message: error.message,
        error_class: error.class.name
      )
      @results[:failed] += 1
      logger.log_task_failure(
        version: task_class.task_version,
        error: error,
        phase: phase
      )
    end

    def lock_adapter
      @lock_adapter ||= LockAdapters::Base.resolve(
        DeploymentTask.configuration.lock_adapter
      )
    end
  end
end
