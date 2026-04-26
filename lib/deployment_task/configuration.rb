# frozen_string_literal: true

require "logger"

module DeploymentTask
  class Configuration
    attr_accessor :task_directory, :error_reporter, :logger,
                  :record_base_class, :lock_adapter

    def initialize
      @task_directory = "lib/deployment_task/tasks"
      @error_reporter = ->(error, context) {}
      @logger = default_logger
      @record_base_class = "ApplicationRecord"
      @lock_adapter = :database
    end

    private

    def default_logger
      if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
        Rails.logger
      else
        ::Logger.new($stdout)
      end
    end
  end
end
