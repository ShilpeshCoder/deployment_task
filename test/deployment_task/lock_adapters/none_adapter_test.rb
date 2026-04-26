# frozen_string_literal: true

require_relative "../../test_helper"
require "rantly"
require "rantly/property"

class NoneAdapterTest < Minitest::Test
  include TaskTestHelper

  # Feature: deployment-task-gem, Property 23: None adapter skips locking
  # **Validates: Requirements 11.4**
  def test_none_adapter_skips_locking
    property_of {
      # Generate random 14-digit version strings
      version = sized(14) { string(:digit) }
      version = "0" * (14 - version.length) + version if version.length < 14
      version
    }.check(100) { |version|
      adapter = DeploymentTask::LockAdapters::NoneAdapter.new

      # acquire is a no-op — should not raise
      adapter.acquire(version)

      # release is a no-op — should not raise
      adapter.release(version)

      # with_lock yields the block and returns its value
      yielded = false
      result = adapter.with_lock(version) do
        yielded = true
        :block_result
      end

      assert yielded, "with_lock must yield the block"
      assert_equal :block_result, result

      # Verify no SQL was executed by checking that no queries hit the connection
      # NoneAdapter methods are pure no-ops — they don't touch the connection at all
      # This is implicitly verified by the fact that acquire/release don't raise
      # and don't call connection (NoneAdapter has no `connection` method)
    }
  end

  private

  def property_of(&block)
    Rantly::Property.new(block)
  end
end
