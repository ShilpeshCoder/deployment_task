# DeploymentTask

A Rails engine for defining and executing one-time deployment tasks with AASM state tracking, idempotency, advisory locking, and CI/CD integration.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "deployment_task"
```

Then execute:

```bash
bundle install
```

Install the initializer and migrations:

```bash
rails generate deployment_task:install
rails deployment_task:install:migrations
rails db:migrate
```

## Configuration

Create or edit `config/initializers/deployment_task.rb`:

```ruby
DeploymentTask.configure do |config|
  # Directory where deployment task files are stored
  config.task_directory = "lib/deployment_task/tasks"

  # Error reporter — any object responding to call(error, context)
  # config.error_reporter = ->(error, context) { Bugsnag.notify(error) }

  # Logger — any Logger-compatible object
  # config.logger = Rails.logger

  # ActiveRecord base class for DeploymentTask::Record
  # config.record_base_class = "ApplicationRecord"

  # Advisory lock strategy: :database (auto-detect) or :none
  # config.lock_adapter = :database
end
```

## Usage

### Generating a Task

```bash
rails generate deployment_task my_task --phase=pre_deploy
```

This creates a task file in your configured task directory:

```ruby
class MyTask < DeploymentTask::Base
  version "20250101120000"
  phase :pre_deploy
  description "Describe what this task does"

  def execute
    # Implement task logic here
  end
end
```

### Running Tasks

```bash
# Run pre-deploy tasks
bundle exec rake deploy:pre

# Run post-deploy tasks
bundle exec rake deploy:post

# Dry run (preview without executing)
DRY_RUN=true bundle exec rake deploy:pre

# Check task status
bundle exec rake deploy:status

# Retry failed tasks
PHASE=pre_deploy bundle exec rake deploy:retry_failed
```

## Requirements

- Ruby >= 2.7.0
- Rails >= 6.0
- AASM >= 5.0

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).
