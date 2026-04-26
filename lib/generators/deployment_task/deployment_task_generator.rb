# frozen_string_literal: true

class DeploymentTaskGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("templates", __dir__)

  class_option :phase, type: :string, required: true,
    desc: "Deployment phase (pre_deploy or post_deploy)"

  VALID_PHASES = %w[pre_deploy post_deploy].freeze

  def validate_phase
    return if VALID_PHASES.include?(options[:phase])

    raise ArgumentError,
      "Invalid phase '#{options[:phase]}'. Must be one of: #{VALID_PHASES.join(', ')}"
  end

  def create_task_file
    @version = Time.now.utc.strftime("%Y%m%d%H%M%S")
    @phase = options[:phase]
    @class_name = file_name.camelize
    task_dir = DeploymentTask.configuration.task_directory
    template "task.rb.tt", "#{task_dir}/#{@version}_#{file_name}.rb"
  end
end
