# frozen_string_literal: true
require 'aasm'

require_relative "deployment_task/version"
require_relative "deployment_task/configuration"
require_relative "deployment_task/base"
require_relative "deployment_task/registry"
require_relative "deployment_task/runner"
require_relative "deployment_task/task_logger"
require_relative "deployment_task/lock_adapters/base"
require_relative "deployment_task/lock_adapters/mysql_adapter"
require_relative "deployment_task/lock_adapters/postgresql_adapter"
require_relative "deployment_task/lock_adapters/none_adapter"

require_relative "deployment_task/engine" if defined?(Rails)

module DeploymentTask
  class Error < StandardError; end
  class DuplicateVersionError < Error; end
  class InvalidVersionError < Error; end
  class LockNotAcquiredError < Error; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset!
      @configuration = Configuration.new
      Registry.reset!
    end
  end
end
