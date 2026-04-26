# frozen_string_literal: true

require_relative "lib/deployment_task/version"

Gem::Specification.new do |spec|
  spec.name          = "deployment_task"
  spec.version       = DeploymentTask::VERSION
  spec.authors       = "Shilpesh Agre"
  spec.email         = "shilpua5@gmail.com"

  spec.summary       = "A Rails engine for defining and executing one-time deployment tasks."
  spec.description   = "Structured framework for pre-deploy and post-deploy tasks with " \
                        "AASM state tracking, idempotency, advisory locking, and CI/CD integration."
  spec.homepage      = "https://github.com/ShilpeshCoder/deployment_task"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata = {
    "homepage_uri"          => spec.homepage,
    "source_code_uri"       => spec.homepage,
    "changelog_uri"         => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.start_with?("test/", "spec/", ".git", ".github", "Gemfile")
    end
  end

  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 6.0"
  spec.add_dependency "aasm", ">= 5.0"
end
