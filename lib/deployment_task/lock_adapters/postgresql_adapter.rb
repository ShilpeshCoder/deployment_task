# frozen_string_literal: true

require "zlib"

module DeploymentTask
  module LockAdapters
    class PostgresqlAdapter < Base
      def acquire(version)
        acquired = connection.select_value(
          "SELECT pg_try_advisory_lock(#{advisory_lock_id(version)})"
        )
        unless acquired
          raise LockNotAcquiredError,
            "Could not acquire lock for task #{version}. " \
            "Another process may be executing it."
        end
      end

      def release(version)
        connection.select_value(
          "SELECT pg_advisory_unlock(#{advisory_lock_id(version)})"
        )
      end

      private

      def advisory_lock_id(version)
        # PostgreSQL advisory locks use bigint keys.
        # CRC32 of the lock key string produces a stable 32-bit integer.
        Zlib.crc32(lock_key(version))
      end

      def connection
        DeploymentTask::Record.connection
      end
    end
  end
end
