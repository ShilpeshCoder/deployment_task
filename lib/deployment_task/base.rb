# frozen_string_literal: true

module DeploymentTask
  class Base
    class << self
      attr_reader :task_version, :task_phase, :task_description

      def version(v)
        @task_version = v.to_s
      end

      def phase(p)
        @task_phase = p.to_sym
      end

      def description(d)
        @task_description = d
      end

      def inherited(subclass)
        super
        DeploymentTask::Registry.register(subclass)
      end

      def task_name
        name&.demodulize&.underscore
      end
    end

    def execute
      raise NotImplementedError, "#{self.class.name} must implement #execute"
    end

    def dry_run_description
      self.class.task_description
    end
  end
end
