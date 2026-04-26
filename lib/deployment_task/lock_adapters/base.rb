# frozen_string_literal: true

module DeploymentTask
  module LockAdapters
    class Base
      def self.resolve(adapter_setting)
        case adapter_setting
        when :none
          NoneAdapter.new
        when :database
          detect_database_adapter
        else
          raise ArgumentError, "Unknown lock_adapter: #{adapter_setting}"
        end
      end

      def self.detect_database_adapter
        adapter_name = DeploymentTask::Record.connection.adapter_name.downcase
        case adapter_name
        when /mysql/
          MysqlAdapter.new
        when /postgresql/, /postgis/
          PostgresqlAdapter.new
        else
          # SQLite and unknown adapters fall back to no-op
          NoneAdapter.new
        end
      end

      def with_lock(version)
        acquire(version)
        yield
      ensure
        release(version)
      end

      def acquire(version)
        raise NotImplementedError
      end

      def release(version)
        raise NotImplementedError
      end

      private

      def lock_key(version)
        "deployment_task:#{version}"
      end
    end
  end
end
