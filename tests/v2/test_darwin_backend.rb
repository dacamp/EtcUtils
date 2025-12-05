# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/etcutils/backend/darwin"

class TestDarwinBackend < Test::Unit::TestCase
  def setup
    super
    skip_unless_macos
    # Re-register the Darwin backend after reset (reset! clears registry)
    EtcUtils::Backend::Registry.register(:darwin, EtcUtils::Backend::Darwin.new)
  end

  def test_backend_registered
    assert_includes EtcUtils::Backend::Registry.registered_platforms, :darwin
  end

  def test_platform_name
    backend = EtcUtils::Backend::Registry.backend_for(:darwin)
    assert_equal :darwin, backend.platform_name
  end

  def test_capabilities
    backend = EtcUtils::Backend::Registry.backend_for(:darwin)
    caps = backend.capabilities

    assert_equal :darwin, caps[:os]
    assert caps[:users][:read]
    refute caps[:users][:write]
    assert caps[:groups][:read]
    refute caps[:groups][:write]
    refute caps[:shadow][:read]
    refute caps[:shadow][:write]
    refute caps[:locking]
  end

  def test_each_user_returns_enumerator
    backend = EtcUtils::Backend::Registry.backend_for(:darwin)
    enum = backend.each_user

    assert_kind_of Enumerator, enum
  end

  def test_each_user_yields_hashes
    backend = EtcUtils::Backend::Registry.backend_for(:darwin)
    users = backend.each_user.take(3)

    users.each do |user|
      assert_kind_of Hash, user
      assert user.key?(:name)
      assert user.key?(:uid)
      assert user.key?(:gid)
      assert user.key?(:dir)
      assert user.key?(:shell)
    end
  end

  def test_find_user_by_name
    backend = EtcUtils::Backend::Registry.backend_for(:darwin)
    user = backend.find_user("root")

    assert_not_nil user
    assert_equal "root", user[:name]
    assert_equal 0, user[:uid]
    assert_equal 0, user[:gid]
  end

  def test_find_user_by_uid
    backend = EtcUtils::Backend::Registry.backend_for(:darwin)
    user = backend.find_user(0)

    assert_not_nil user
    assert_equal "root", user[:name]
    assert_equal 0, user[:uid]
  end

  def test_find_user_not_found
    backend = EtcUtils::Backend::Registry.backend_for(:darwin)
    user = backend.find_user("nonexistent_user_xyz")

    assert_nil user
  end

  def test_each_group_returns_enumerator
    backend = EtcUtils::Backend::Registry.backend_for(:darwin)
    enum = backend.each_group

    assert_kind_of Enumerator, enum
  end

  def test_each_group_yields_hashes
    backend = EtcUtils::Backend::Registry.backend_for(:darwin)
    groups = backend.each_group.take(3)

    groups.each do |group|
      assert_kind_of Hash, group
      assert group.key?(:name)
      assert group.key?(:gid)
      assert group.key?(:members)
      assert_kind_of Array, group[:members]
    end
  end

  def test_find_group_by_name
    backend = EtcUtils::Backend::Registry.backend_for(:darwin)
    group = backend.find_group("wheel")

    assert_not_nil group
    assert_equal "wheel", group[:name]
    assert_equal 0, group[:gid]
  end

  def test_find_group_by_gid
    backend = EtcUtils::Backend::Registry.backend_for(:darwin)
    group = backend.find_group(0)

    assert_not_nil group
    assert_equal "wheel", group[:name]
    assert_equal 0, group[:gid]
  end

  def test_find_group_not_found
    backend = EtcUtils::Backend::Registry.backend_for(:darwin)
    group = backend.find_group("nonexistent_group_xyz")

    assert_nil group
  end

  def test_shadow_raises_unsupported
    backend = EtcUtils::Backend::Registry.backend_for(:darwin)

    assert_raise(EtcUtils::UnsupportedError) do
      backend.each_shadow.to_a
    end
  end

  def test_gshadow_raises_unsupported
    backend = EtcUtils::Backend::Registry.backend_for(:darwin)

    assert_raise(EtcUtils::UnsupportedError) do
      backend.each_gshadow.to_a
    end
  end

  def test_write_passwd_raises_unsupported
    backend = EtcUtils::Backend::Registry.backend_for(:darwin)

    assert_raise(EtcUtils::UnsupportedError) do
      backend.write_passwd([])
    end
  end

  def test_with_lock_raises_unsupported
    backend = EtcUtils::Backend::Registry.backend_for(:darwin)

    assert_raise(EtcUtils::UnsupportedError) do
      backend.with_lock { }
    end
  end

  def test_locked_returns_false
    backend = EtcUtils::Backend::Registry.backend_for(:darwin)
    refute backend.locked?
  end
end
