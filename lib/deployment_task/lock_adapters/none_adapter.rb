# frozen_string_literal: true

module DeploymentTask
  module LockAdapters
    class NoneAdapter < Base
      def acquire(_version)
        # No-op: rely on database unique constraint for idempotency
      end

      def release(_version)
        # No-op
      end
    end
  end
end
