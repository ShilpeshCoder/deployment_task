# frozen_string_literal: true

module DeploymentTask
  class Engine < ::Rails::Engine
    isolate_namespace DeploymentTask

    initializer "deployment_task.load_rake_tasks" do
      # Rake tasks are loaded automatically by the engine
    end

    initializer "deployment_task.configure_record_base" do
      ActiveSupport.on_load(:active_record) do
        base_class = DeploymentTask.configuration.record_base_class
        DeploymentTask::Record.table_name = "deployment_task_records"
      end
    end
  end
end
