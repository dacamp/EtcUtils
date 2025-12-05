# frozen_string_literal: true

require_relative "test_helper"

class TestPlatform < Test::Unit::TestCase
  def test_os_returns_symbol
    os = EtcUtils::Platform.os
    assert_kind_of Symbol, os
    assert_includes %i[linux darwin windows unknown], os
  end

  def test_os_version_returns_string
    version = EtcUtils::Platform.os_version
    assert_kind_of String, version
    refute_empty version unless version == "unknown"
  end

  def test_supports_users
    assert EtcUtils::Platform.supports?(:users)
  end

  def test_supports_groups
    assert EtcUtils::Platform.supports?(:groups)
  end

  def test_supports_shadow_on_linux
    skip_unless_linux

    assert EtcUtils::Platform.supports?(:shadow)
  end

  def test_supports_shadow_false_on_macos
    skip_unless_macos

    refute EtcUtils::Platform.supports?(:shadow)
  end

  def test_supports_gshadow_on_linux
    skip_unless_linux

    assert EtcUtils::Platform.supports?(:gshadow)
  end

  def test_supports_gshadow_false_on_macos
    skip_unless_macos

    refute EtcUtils::Platform.supports?(:gshadow)
  end

  def test_supports_users_write_on_linux
    skip_unless_linux

    assert EtcUtils::Platform.supports?(:users_write)
  end

  def test_supports_users_write_false_on_macos
    skip_unless_macos

    refute EtcUtils::Platform.supports?(:users_write)
  end

  def test_supports_locking_on_linux
    skip_unless_linux

    assert EtcUtils::Platform.supports?(:locking)
  end

  def test_supports_locking_false_on_macos
    skip_unless_macos

    refute EtcUtils::Platform.supports?(:locking)
  end

  def test_supports_unknown_feature_returns_false
    refute EtcUtils::Platform.supports?(:nonexistent_feature)
  end

  def test_capabilities_returns_hash
    caps = EtcUtils::Platform.capabilities

    assert_kind_of Hash, caps
    assert caps.key?(:os)
    assert caps.key?(:os_version)
    assert caps.key?(:etcutils_version)
    assert caps.key?(:users)
    assert caps.key?(:groups)
    assert caps.key?(:shadow)
    assert caps.key?(:gshadow)
    assert caps.key?(:locking)
  end

  def test_capabilities_nested_structure
    caps = EtcUtils::Platform.capabilities

    assert_kind_of Hash, caps[:users]
    assert caps[:users].key?(:read)
    assert caps[:users].key?(:write)

    assert_kind_of Hash, caps[:groups]
    assert caps[:groups].key?(:read)
    assert caps[:groups].key?(:write)

    assert_kind_of Hash, caps[:shadow]
    assert caps[:shadow].key?(:read)
    assert caps[:shadow].key?(:write)

    assert_kind_of Hash, caps[:gshadow]
    assert caps[:gshadow].key?(:read)
    assert caps[:gshadow].key?(:write)
  end

  def test_capabilities_on_linux
    skip_unless_linux

    caps = EtcUtils::Platform.capabilities

    assert_equal :linux, caps[:os]
    assert caps[:users][:read]
    assert caps[:users][:write]
    assert caps[:groups][:read]
    assert caps[:groups][:write]
    assert caps[:shadow][:read]
    assert caps[:shadow][:write]
    assert caps[:gshadow][:read]
    assert caps[:gshadow][:write]
    assert caps[:locking]
  end

  def test_capabilities_on_macos
    skip_unless_macos

    caps = EtcUtils::Platform.capabilities

    assert_equal :darwin, caps[:os]
    assert caps[:users][:read]
    refute caps[:users][:write]
    assert caps[:groups][:read]
    refute caps[:groups][:write]
    refute caps[:shadow][:read]
    refute caps[:shadow][:write]
    refute caps[:gshadow][:read]
    refute caps[:gshadow][:write]
    refute caps[:locking]
  end

  def test_capabilities_includes_version
    caps = EtcUtils::Platform.capabilities

    assert_equal EtcUtils::VERSION, caps[:etcutils_version]
  end

  def test_reset_clears_cached_values
    # Force caching
    EtcUtils::Platform.os
    EtcUtils::Platform.capabilities

    # Reset
    EtcUtils::Platform.reset!

    # Should re-detect (hard to test, but at least ensure no errors)
    assert_kind_of Symbol, EtcUtils::Platform.os
    assert_kind_of Hash, EtcUtils::Platform.capabilities
  end
end
