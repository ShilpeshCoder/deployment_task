# frozen_string_literal: true

module DeploymentTask
  module LockAdapters
    class MysqlAdapter < Base
      LOCK_TIMEOUT = 0 # Non-blocking

      def acquire(version)
        result = connection.select_value(
          "SELECT GET_LOCK(#{connection.quote(lock_key(version))}, #{LOCK_TIMEOUT})"
        )
        unless result == 1
          raise LockNotAcquiredError,
            "Could not acquire lock for task #{version}. " \
            "Another process may be executing it."
        end
      end

      def release(version)
        connection.select_value(
          "SELECT RELEASE_LOCK(#{connection.quote(lock_key(version))})"
        )
      end

      private

      def connection
        DeploymentTask::Record.connection
      end
    end
  end
end
