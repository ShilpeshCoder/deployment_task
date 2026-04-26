# frozen_string_literal: true

class CreateDeploymentTaskRecords < ActiveRecord::Migration[6.0]
  def change
    create_table :deployment_task_records do |t|
      t.string :version, null: false
      t.string :phase, null: false
      t.string :status, null: false, default: "pending"
      t.string :task_name, null: false
      t.string :description
      t.datetime :started_at
      t.datetime :completed_at
      t.text :error_message
      t.string :error_class
      t.float :execution_time_seconds
      t.string :execution_id

      t.timestamps
    end

    add_index :deployment_task_records, :version, unique: true
    add_index :deployment_task_records, [:phase, :status]
    add_index :deployment_task_records, :execution_id
  end
end
