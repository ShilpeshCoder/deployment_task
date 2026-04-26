# frozen_string_literal: true

module DeploymentTask
  class Record < ActiveRecord::Base
    self.table_name = "deployment_task_records"

    include AASM

    aasm column: :status do
      state :pending, initial: true
      state :running
      state :completed
      state :failed
      state :skipped

      event :start do
        transitions from: %i[pending], to: :running
        after { update!(started_at: Time.now.utc) }
      end

      event :complete do
        transitions from: :running, to: :completed
        after do
          now = Time.now.utc
          update!(
            completed_at: now,
            execution_time_seconds: started_at ? (now - started_at).round(2) : nil
          )
        end
      end

      event :fail do
        transitions from: :running, to: :failed
        after { update!(completed_at: Time.now.utc) }
      end

      event :skip do
        transitions from: :pending, to: :skipped
      end

      event :reset do
        transitions from: :failed, to: :pending
        after do
          update!(
            started_at: nil, completed_at: nil,
            error_message: nil, error_class: nil,
            execution_time_seconds: nil
          )
        end
      end
    end

    validates :version, presence: true, uniqueness: true
    validates :phase, presence: true, inclusion: { in: %w[pre_deploy post_deploy] }
    validates :task_name, presence: true

    scope :for_phase, ->(phase) { where(phase: phase) }
    scope :failed_tasks, -> { where(status: :failed) }
  end
end
