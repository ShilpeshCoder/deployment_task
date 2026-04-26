# frozen_string_literal: true

module DeploymentTask
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def copy_initializer
        template "initializer.rb.tt",
          "config/initializers/deployment_task.rb"
      end

      def show_migration_instructions
        say "Run `rails deployment_task:install:migrations` to install migrations."
        say "Then run `rails db:migrate` to create the deployment_task_records table."
      end
    end
  end
end
