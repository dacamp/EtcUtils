# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/etcutils/backend/linux"

class TestLinuxBackend < Test::Unit::TestCase
  def setup
    super
    skip_unless_linux
    # Re-register the Linux backend after reset
    EtcUtils::Backend::Registry.register(:linux, EtcUtils::Backend::Linux.new)
  end

  def test_backend_registered
    assert_includes EtcUtils::Backend::Registry.registered_platforms, :linux
  end

  def test_platform_name
    backend = EtcUtils::Backend::Registry.backend_for(:linux)
    assert_equal :linux, backend.platform_name
  end

  def test_capabilities
    backend = EtcUtils::Backend::Registry.backend_for(:linux)
    caps = backend.capabilities

    assert_equal :linux, caps[:os]
    assert caps[:users][:read]
    assert caps[:users][:write]
    assert caps[:groups][:read]
    assert caps[:groups][:write]
    assert caps[:shadow][:read]
    assert caps[:shadow][:write]
    assert caps[:locking]
  end

  def test_each_user_returns_enumerator
    backend = EtcUtils::Backend::Registry.backend_for(:linux)
    enum = backend.each_user

    assert_kind_of Enumerator, enum
  end

  def test_each_user_yields_hashes
    backend = EtcUtils::Backend::Registry.backend_for(:linux)
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
    backend = EtcUtils::Backend::Registry.backend_for(:linux)
    user = backend.find_user("root")

    assert_not_nil user
    assert_equal "root", user[:name]
    assert_equal 0, user[:uid]
  end

  def test_find_user_by_uid
    backend = EtcUtils::Backend::Registry.backend_for(:linux)
    user = backend.find_user(0)

    assert_not_nil user
    assert_equal "root", user[:name]
    assert_equal 0, user[:uid]
  end

  def test_find_user_not_found
    backend = EtcUtils::Backend::Registry.backend_for(:linux)
    user = backend.find_user("nonexistent_user_xyz")

    assert_nil user
  end

  def test_each_group_returns_enumerator
    backend = EtcUtils::Backend::Registry.backend_for(:linux)
    enum = backend.each_group

    assert_kind_of Enumerator, enum
  end

  def test_each_group_yields_hashes
    backend = EtcUtils::Backend::Registry.backend_for(:linux)
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
    backend = EtcUtils::Backend::Registry.backend_for(:linux)
    group = backend.find_group("root")

    assert_not_nil group
    assert_equal "root", group[:name]
    assert_equal 0, group[:gid]
  end

  def test_find_group_by_gid
    backend = EtcUtils::Backend::Registry.backend_for(:linux)
    group = backend.find_group(0)

    assert_not_nil group
    assert_equal "root", group[:name]
    assert_equal 0, group[:gid]
  end

  def test_find_group_not_found
    backend = EtcUtils::Backend::Registry.backend_for(:linux)
    group = backend.find_group("nonexistent_group_xyz")

    assert_nil group
  end

  # Shadow tests require root or shadow group membership
  def test_each_shadow_requires_permission
    backend = EtcUtils::Backend::Registry.backend_for(:linux)

    # This may pass if running as root, or fail with PermissionError
    begin
      shadows = backend.each_shadow.take(1)
      assert_kind_of Array, shadows
    rescue EtcUtils::PermissionError => e
      assert_match(/shadow/, e.message)
    end
  end

  def test_locked_returns_false_initially
    backend = EtcUtils::Backend::Registry.backend_for(:linux)
    refute backend.locked?
  end
end

# Separate test class for write operations (require root)
class TestLinuxBackendWriteOperations < Test::Unit::TestCase
  def setup
    super
    skip_unless_linux
    skip_if_v1_extension("Write tests require v2 User class")
    omit("Write tests require root") unless Process.uid.zero?
    EtcUtils::Backend::Registry.register(:linux, EtcUtils::Backend::Linux.new)
  end

  def test_write_passwd_dry_run
    backend = EtcUtils::Backend::Registry.backend_for(:linux)

    # Read current users
    users = backend.each_user.map { |u| EtcUtils::User.new(**u) }

    result = backend.write_passwd(users, dry_run: true)

    assert_kind_of EtcUtils::DryRunResult, result
    assert result.valid?
    assert_equal users.length, result.entry_count
  end

  def test_with_lock
    backend = EtcUtils::Backend::Registry.backend_for(:linux)

    result = backend.with_lock do
      assert backend.locked?
      :completed
    end

    assert_equal :completed, result
    refute backend.locked?
  end
end
