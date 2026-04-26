# frozen_string_literal: true

module TaskTestHelper
  # Creates an anonymous task class with valid metadata for testing.
  # The class is NOT assigned to a constant, so it won't pollute the namespace.
  #
  # @param version [String] 14-digit timestamp version (e.g., "20250101120000")
  # @param phase [Symbol] :pre_deploy or :post_deploy
  # @param description [String] human-readable task description
  # @param block [Proc] optional block that becomes the #execute method
  # @return [Class] anonymous subclass of DeploymentTask::Base
  def create_task_class(version:, phase: :post_deploy, description: "Test task", &block)
    klass = Class.new(DeploymentTask::Base) do
      self.version(version)
      self.phase(phase)
      self.description(description)

      if block
        define_method(:execute, &block)
      else
        define_method(:execute) { } # no-op
      end
    end
    klass
  end

  # Generates a valid 14-digit timestamp version string.
  # Useful for quickly creating unique versions in tests.
  #
  # @param offset [Integer] seconds to add to base time for uniqueness
  # @return [String] 14-digit version string
  def generate_version(offset = 0)
    (Time.utc(2025, 1, 1) + offset).strftime("%Y%m%d%H%M%S")
  end
end
