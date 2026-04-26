# frozen_string_literal: true

namespace :deploy do
  desc "Run pending pre-deploy tasks"
  task pre: :environment do
    dry_run = ENV["DRY_RUN"] == "true"
    DeploymentTask::Registry.load_tasks!
    success = DeploymentTask::Runner.new(phase: :pre_deploy, dry_run: dry_run).run
    exit(1) unless success
  end

  desc "Run pending post-deploy tasks"
  task post: :environment do
    dry_run = ENV["DRY_RUN"] == "true"
    DeploymentTask::Registry.load_tasks!
    success = DeploymentTask::Runner.new(phase: :post_deploy, dry_run: dry_run).run
    exit(1) unless success
  end

  desc "Show status of recent deployment task records"
  task status: :environment do
    records = DeploymentTask::Record.order(version: :desc).limit(50)
    records.each do |r|
      puts "#{r.version} | #{r.phase} | #{r.status} | " \
           "#{r.task_name} | #{r.started_at} | #{r.completed_at}"
    end
  end

  desc "Retry all failed tasks in a given phase (PHASE=pre_deploy|post_deploy)"
  task retry_failed: :environment do
    phase = ENV.fetch("PHASE") do
      abort "PHASE env var required (pre_deploy or post_deploy)"
    end
    DeploymentTask::Registry.load_tasks!
    success = DeploymentTask::Runner.new(phase: phase.to_sym).run
    exit(1) unless success
  end
end
