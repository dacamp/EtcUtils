# frozen_string_literal: true

require_relative "test_helper"

class TestBackendRegistry < Test::Unit::TestCase
  def setup
    super
    EtcUtils::Backend::Registry.reset!
  end

  def teardown
    EtcUtils::Backend::Registry.reset!
  end

  def test_register_and_retrieve_backend
    mock_backend = MockBackend.new
    EtcUtils::Backend::Registry.register(:test, mock_backend)

    retrieved = EtcUtils::Backend::Registry.backend_for(:test)
    assert_same mock_backend, retrieved
  end

  def test_backend_for_unregistered_raises_unsupported_error
    assert_raise(EtcUtils::UnsupportedError) do
      EtcUtils::Backend::Registry.backend_for(:nonexistent)
    end
  end

  def test_unregister_backend
    mock_backend = MockBackend.new
    EtcUtils::Backend::Registry.register(:test, mock_backend)
    EtcUtils::Backend::Registry.unregister(:test)

    assert_raise(EtcUtils::UnsupportedError) do
      EtcUtils::Backend::Registry.backend_for(:test)
    end
  end

  def test_registered_platforms
    EtcUtils::Backend::Registry.register(:platform1, MockBackend.new)
    EtcUtils::Backend::Registry.register(:platform2, MockBackend.new)

    platforms = EtcUtils::Backend::Registry.registered_platforms
    assert_includes platforms, :platform1
    assert_includes platforms, :platform2
  end

  def test_current_raises_when_no_backend_registered
    # After reset, no backends are registered
    assert_raise(EtcUtils::UnsupportedError) do
      EtcUtils::Backend::Registry.current
    end
  end

  def test_current_returns_backend_for_current_platform
    # Register a backend for the current platform
    mock_backend = MockBackend.new
    current_os = EtcUtils::Platform.os
    EtcUtils::Backend::Registry.register(current_os, mock_backend)

    retrieved = EtcUtils::Backend::Registry.current
    assert_same mock_backend, retrieved
  end

  def test_current_is_cached
    mock_backend = MockBackend.new
    current_os = EtcUtils::Platform.os
    EtcUtils::Backend::Registry.register(current_os, mock_backend)

    first_call = EtcUtils::Backend::Registry.current
    second_call = EtcUtils::Backend::Registry.current

    assert_same first_call, second_call
  end

  def test_reset_clears_current_cache
    mock_backend = MockBackend.new
    current_os = EtcUtils::Platform.os
    EtcUtils::Backend::Registry.register(current_os, mock_backend)

    EtcUtils::Backend::Registry.current # cache it
    EtcUtils::Backend::Registry.reset!

    # After reset, should raise because backends are cleared
    assert_raise(EtcUtils::UnsupportedError) do
      EtcUtils::Backend::Registry.current
    end
  end

  class MockBackend < EtcUtils::Backend::Base
    def platform_name
      :mock
    end

    def capabilities
      {
        users: { read: true, write: false },
        groups: { read: true, write: false },
        shadow: { read: false, write: false },
        gshadow: { read: false, write: false },
        locking: false
      }
    end
  end
end
