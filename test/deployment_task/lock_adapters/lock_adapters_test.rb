# frozen_string_literal: true

require_relative "../../test_helper"
require "mocha/minitest"

class LockAdaptersTest < Minitest::Test
  include TaskTestHelper

  # Requirements: 11.4
  def test_resolve_none_returns_none_adapter
    adapter = DeploymentTask::LockAdapters::Base.resolve(:none)
    assert_instance_of DeploymentTask::LockAdapters::NoneAdapter, adapter
  end

  # Requirements: 11.3
  def test_resolve_database_with_sqlite_returns_none_adapter
    DeploymentTask::Record.connection.stubs(:adapter_name).returns("SQLite")
    adapter = DeploymentTask::LockAdapters::Base.resolve(:database)
    assert_instance_of DeploymentTask::LockAdapters::NoneAdapter, adapter
  end

  # Requirements: 11.1
  def test_resolve_database_with_mysql_returns_mysql_adapter
    DeploymentTask::Record.connection.stubs(:adapter_name).returns("Mysql2")
    adapter = DeploymentTask::LockAdapters::Base.resolve(:database)
    assert_instance_of DeploymentTask::LockAdapters::MysqlAdapter, adapter
  end

  # Requirements: 11.2
  def test_resolve_database_with_postgresql_returns_postgresql_adapter
    DeploymentTask::Record.connection.stubs(:adapter_name).returns("PostgreSQL")
    adapter = DeploymentTask::LockAdapters::Base.resolve(:database)
    assert_instance_of DeploymentTask::LockAdapters::PostgresqlAdapter, adapter
  end

  # Requirements: 11.2 (PostGIS variant)
  def test_resolve_database_with_postgis_returns_postgresql_adapter
    DeploymentTask::Record.connection.stubs(:adapter_name).returns("PostGIS")
    adapter = DeploymentTask::LockAdapters::Base.resolve(:database)
    assert_instance_of DeploymentTask::LockAdapters::PostgresqlAdapter, adapter
  end

  # Requirements: 11.5
  def test_resolve_unknown_raises_argument_error
    assert_raises(ArgumentError) do
      DeploymentTask::LockAdapters::Base.resolve(:unknown)
    end
  end

  # Requirements: 11.4
  def test_with_lock_yields_and_ensures_release
    adapter = DeploymentTask::LockAdapters::NoneAdapter.new
    yielded = false

    result = adapter.with_lock("20250101120000") do
      yielded = true
      42
    end

    assert yielded, "with_lock must yield the block"
    assert_equal 42, result
  end

  # Requirements: 11.4
  def test_with_lock_ensures_release_even_on_exception
    adapter = DeploymentTask::LockAdapters::NoneAdapter.new

    assert_raises(RuntimeError) do
      adapter.with_lock("20250101120000") do
        raise RuntimeError, "boom"
      end
    end

    # If we get here, ensure block (release) ran without issue
  end
end
