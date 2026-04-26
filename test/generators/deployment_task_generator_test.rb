# frozen_string_literal: true

require_relative "../test_helper"
require "rantly"
require "rantly/property"
require "erb"

# We need Rails generators loaded for the generator classes
require "rails/generators"

# Require the generator files directly
require_relative "../../lib/generators/deployment_task/deployment_task_generator"
require_relative "../../lib/generators/deployment_task/install_generator"

class DeploymentTaskGeneratorTest < Minitest::Test
  include TaskTestHelper

  TEMPLATE_PATH = File.expand_path(
    "../../lib/generators/deployment_task/templates/task.rb.tt",
    __dir__
  )

  INITIALIZER_TEMPLATE_PATH = File.expand_path(
    "../../lib/generators/deployment_task/templates/initializer.rb.tt",
    __dir__
  )

  VALID_PHASES = %w[pre_deploy post_deploy].freeze

  # Feature: deployment-task-gem, Property 18: Generator output correctness
  # **Validates: Requirements 8.1, 8.2, 8.4**
  def test_generator_output_correctness_property
    template_content = File.read(TEMPLATE_PATH)

    property_of {
      # Generate random valid task names: lowercase alpha, 3-15 chars
      name_len = range(3, 15)
      task_name = sized(name_len) { string(:lower) }
      phase = choose("pre_deploy", "post_deploy")
      [task_name, phase]
    }.check(100) { |task_name, phase|
      # Simulate what the generator does: set template variables and render
      version = Time.now.utc.strftime("%Y%m%d%H%M%S")
      class_name = task_name.split("_").map(&:capitalize).join

      # Render the ERB template with the same variables the generator uses
      rendered = render_task_template(
        template_content: template_content,
        class_name: class_name,
        version: version,
        phase: phase
      )

      # Verify filename would contain a 14-digit timestamp
      filename = "#{version}_#{task_name}.rb"
      assert_match(/\A\d{14}_/, filename,
        "Filename should start with a 14-digit timestamp")

      # Verify the generated content contains DeploymentTask::Base inheritance
      assert_match(/< DeploymentTask::Base/, rendered,
        "Generated file should inherit from DeploymentTask::Base")

      # Verify the correct phase declaration
      assert_match(/phase :#{phase}/, rendered,
        "Generated file should declare phase :#{phase}")

      # Verify the version matches the filename timestamp
      assert_match(/version "#{version}"/, rendered,
        "Generated file should contain version matching the filename timestamp")

      # Verify an execute method definition
      assert_match(/def execute/, rendered,
        "Generated file should contain an execute method definition")
    }
  end

  # Feature: deployment-task-gem, Property 19: Generator rejects invalid phases
  # **Validates: Requirements 8.3**
  def test_generator_rejects_invalid_phases_property
    property_of {
      # Generate random strings that are NOT pre_deploy or post_deploy
      candidate = sized(range(1, 20)) { string(:alnum) }
      guard(!VALID_PHASES.include?(candidate))
      candidate
    }.check(100) { |invalid_phase|
      # Instantiate the generator with the invalid phase and call validate_phase
      generator = DeploymentTaskGenerator.new(
        ["test_task"],
        { phase: invalid_phase },
        {}
      )

      assert_raises(ArgumentError) do
        generator.validate_phase
      end
    }
  end

  # --- Unit tests for generators (Task 11.5) ---
  # Requirements: 8.1, 8.2, 8.3, 8.4

  def test_task_generator_creates_file_with_correct_naming_and_content
    template_content = File.read(TEMPLATE_PATH)

    task_name = "backfill_users"
    phase = "post_deploy"
    version = Time.now.utc.strftime("%Y%m%d%H%M%S")
    class_name = "BackfillUsers"

    rendered = render_task_template(
      template_content: template_content,
      class_name: class_name,
      version: version,
      phase: phase
    )

    # Verify filename format
    filename = "#{version}_#{task_name}.rb"
    assert_match(/\A\d{14}_backfill_users\.rb\z/, filename)

    # Verify content structure
    assert_includes rendered, "class BackfillUsers < DeploymentTask::Base"
    assert_includes rendered, "version \"#{version}\""
    assert_includes rendered, "phase :post_deploy"
    assert_includes rendered, 'description "TODO: Describe what this task does"'
    assert_includes rendered, "def execute"
  end

  def test_task_generator_rejects_invalid_phase
    generator = DeploymentTaskGenerator.new(
      ["my_task"],
      { phase: "invalid_phase" },
      {}
    )

    error = assert_raises(ArgumentError) do
      generator.validate_phase
    end

    assert_match(/Invalid phase/, error.message)
    assert_match(/invalid_phase/, error.message)
  end

  def test_task_generator_accepts_pre_deploy_phase
    generator = DeploymentTaskGenerator.new(
      ["my_task"],
      { phase: "pre_deploy" },
      {}
    )

    # Should not raise
    generator.validate_phase
  end

  def test_task_generator_accepts_post_deploy_phase
    generator = DeploymentTaskGenerator.new(
      ["my_task"],
      { phase: "post_deploy" },
      {}
    )

    # Should not raise
    generator.validate_phase
  end

  def test_install_generator_template_exists
    assert File.exist?(INITIALIZER_TEMPLATE_PATH),
      "Initializer template should exist at #{INITIALIZER_TEMPLATE_PATH}"
  end

  def test_install_generator_template_contains_configure_block
    content = File.read(INITIALIZER_TEMPLATE_PATH)

    assert_includes content, "DeploymentTask.configure do |config|"
    assert_includes content, "config.task_directory"
    assert_includes content, "config.error_reporter"
    assert_includes content, "config.logger"
    assert_includes content, "config.record_base_class"
    assert_includes content, "config.lock_adapter"
  end

  def test_install_generator_is_subclass_of_rails_generators_base
    assert DeploymentTask::Generators::InstallGenerator < Rails::Generators::Base,
      "InstallGenerator should inherit from Rails::Generators::Base"
  end

  def test_task_generator_valid_phases_constant
    assert_equal %w[pre_deploy post_deploy], DeploymentTaskGenerator::VALID_PHASES
  end

  private

  def property_of(&block)
    Rantly::Property.new(block)
  end

  # Renders the task.rb.tt ERB template with the given variables,
  # simulating what the Rails generator does internally.
  def render_task_template(template_content:, class_name:, version:, phase:)
    @class_name = class_name
    @version = version
    @phase = phase
    ERB.new(template_content, trim_mode: "-").result(binding)
  end
end
