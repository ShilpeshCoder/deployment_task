# frozen_string_literal: true

require "pathname"

module DeploymentTask
  class Registry
    VERSION_FORMAT = /\A\d{14}\z/

    class << self
      def register(task_class)
        registered_classes << task_class
      end

      def tasks_for_phase(phase)
        validate_all!
        registry
          .select { |_version, entry| entry[:phase] == phase.to_sym }
          .sort_by { |version, _entry| version }
          .map { |_version, entry| entry[:task_class] }
      end

      def all_tasks
        validate_all!
        registry.sort_by { |version, _| version }.map { |_, entry| entry }
      end

      def reset!
        @registry = nil
        @registered_classes = nil
        @validated = false
      end

      def load_tasks!
        task_dir = DeploymentTask.configuration.task_directory
        full_path = defined?(Rails) ? Rails.root.join(task_dir) : Pathname.new(task_dir)
        Dir[full_path.join("**/*.rb")].sort.each { |f| require f }
      end

      private

      def registered_classes
        @registered_classes ||= []
      end

      def registry
        @registry ||= {}
      end

      def validate_all!
        return if @validated

        registered_classes.each do |task_class|
          validate_and_add!(task_class)
        end
        @validated = true
      end

      def validate_and_add!(task_class)
        version = task_class.task_version
        phase = task_class.task_phase

        unless version.is_a?(String) && !version.empty? && VERSION_FORMAT.match?(version)
          raise InvalidVersionError,
            "Task #{task_class.name} has invalid version '#{version}'. " \
            "Must be 14-digit timestamp (YYYYMMDDHHmmss)."
        end

        if registry.key?(version)
          raise DuplicateVersionError,
            "Duplicate version '#{version}' between " \
            "#{registry[version][:task_class].name} and #{task_class.name}"
        end

        registry[version] = { task_class: task_class, phase: phase }
      end
    end
  end
end
