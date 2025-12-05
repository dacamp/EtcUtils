# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/etcutils/backend/windows"

class TestWindowsBackend < Test::Unit::TestCase
  def setup
    super
    skip_on_macos("Windows backend only runs on Windows")
    skip_on_linux("Windows backend only runs on Windows")
    # Re-register the Windows backend after reset
    EtcUtils::Backend::Registry.register(:windows, EtcUtils::Backend::Windows.new)
  end

  def test_backend_registered
    assert_includes EtcUtils::Backend::Registry.registered_platforms, :windows
  end

  def test_platform_name
    backend = EtcUtils::Backend::Registry.backend_for(:windows)
    assert_equal :windows, backend.platform_name
  end

  def test_capabilities
    backend = EtcUtils::Backend::Registry.backend_for(:windows)
    caps = backend.capabilities

    assert_equal :windows, caps[:os]
    assert caps[:users][:read]
    refute caps[:users][:write]
    assert caps[:groups][:read]
    refute caps[:groups][:write]
    refute caps[:shadow][:read]
    refute caps[:shadow][:write]
    refute caps[:locking]
  end

  def test_each_user_returns_enumerator
    backend = EtcUtils::Backend::Registry.backend_for(:windows)
    enum = backend.each_user

    assert_kind_of Enumerator, enum
  end

  def test_each_user_yields_hashes
    backend = EtcUtils::Backend::Registry.backend_for(:windows)
    users = backend.each_user.take(3)

    users.each do |user|
      assert_kind_of Hash, user
      assert user.key?(:name)
      assert user.key?(:uid)
      assert user.key?(:gid)
      assert user.key?(:sid) # Windows-specific
    end
  end

  def test_find_user_by_name
    backend = EtcUtils::Backend::Registry.backend_for(:windows)
    user = backend.find_user("Administrator")

    # Administrator may or may not exist depending on system config
    if user
      assert_equal "Administrator", user[:name]
      assert_not_nil user[:uid]
      assert_not_nil user[:sid]
    end
  end

  def test_find_user_not_found
    backend = EtcUtils::Backend::Registry.backend_for(:windows)
    user = backend.find_user("nonexistent_user_xyz")

    assert_nil user
  end

  def test_each_group_returns_enumerator
    backend = EtcUtils::Backend::Registry.backend_for(:windows)
    enum = backend.each_group

    assert_kind_of Enumerator, enum
  end

  def test_each_group_yields_hashes
    backend = EtcUtils::Backend::Registry.backend_for(:windows)
    groups = backend.each_group.take(3)

    groups.each do |group|
      assert_kind_of Hash, group
      assert group.key?(:name)
      assert group.key?(:gid)
      assert group.key?(:members)
      assert group.key?(:sid) # Windows-specific
      assert_kind_of Array, group[:members]
    end
  end

  def test_find_group_by_name
    backend = EtcUtils::Backend::Registry.backend_for(:windows)
    group = backend.find_group("Administrators")

    if group
      assert_equal "Administrators", group[:name]
      assert_not_nil group[:gid]
      assert_not_nil group[:sid]
      assert_kind_of Array, group[:members]
    end
  end

  def test_find_group_not_found
    backend = EtcUtils::Backend::Registry.backend_for(:windows)
    group = backend.find_group("nonexistent_group_xyz")

    assert_nil group
  end

  def test_shadow_raises_unsupported
    backend = EtcUtils::Backend::Registry.backend_for(:windows)

    assert_raise(EtcUtils::UnsupportedError) do
      backend.each_shadow.to_a
    end
  end

  def test_gshadow_raises_unsupported
    backend = EtcUtils::Backend::Registry.backend_for(:windows)

    assert_raise(EtcUtils::UnsupportedError) do
      backend.each_gshadow.to_a
    end
  end

  def test_write_passwd_raises_unsupported
    backend = EtcUtils::Backend::Registry.backend_for(:windows)

    assert_raise(EtcUtils::UnsupportedError) do
      backend.write_passwd([])
    end
  end

  def test_with_lock_raises_unsupported
    backend = EtcUtils::Backend::Registry.backend_for(:windows)

    assert_raise(EtcUtils::UnsupportedError) do
      backend.with_lock { }
    end
  end

  def test_locked_returns_false
    backend = EtcUtils::Backend::Registry.backend_for(:windows)
    refute backend.locked?
  end
end
