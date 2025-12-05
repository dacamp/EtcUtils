# frozen_string_literal: true

require_relative "test_helper"

# Load the darwin backend if on macOS
if MACOS
  require_relative "../../lib/etcutils/backend/darwin"
end

class TestIntegration < Test::Unit::TestCase
  def setup
    super
    # Skip all v2 integration tests when v1 C extension is loaded
    # (v2 collections use Struct-based classes with keyword init)
    skip_if_v1_extension("Integration tests require v2 classes")
    # Re-register the backend after reset
    if MACOS
      EtcUtils::Backend::Registry.register(:darwin, EtcUtils::Backend::Darwin.new)
    end
  end

  def test_users_returns_collection
    skip_on_windows("Backend not implemented for Windows yet")

    users = EtcUtils.users
    assert_kind_of EtcUtils::UserCollection, users
  end

  def test_users_each_yields_user_objects
    skip_on_windows("Backend not implemented for Windows yet")

    EtcUtils.users.take(3).each do |user|
      assert_kind_of EtcUtils::User, user
      assert_respond_to user, :name
      assert_respond_to user, :uid
      assert_respond_to user, :gid
      assert_respond_to user, :dir
      assert_respond_to user, :shell
    end
  end

  def test_users_get_by_name
    skip_on_windows("Backend not implemented for Windows yet")

    user = EtcUtils.users.get("root")
    assert_not_nil user
    assert_equal "root", user.name
    assert_equal 0, user.uid
  end

  def test_users_get_by_uid
    skip_on_windows("Backend not implemented for Windows yet")

    user = EtcUtils.users.get(0)
    assert_not_nil user
    assert_equal 0, user.uid
  end

  def test_users_bracket_shorthand
    skip_on_windows("Backend not implemented for Windows yet")

    user = EtcUtils.users["root"]
    assert_not_nil user
    assert_equal "root", user.name
  end

  def test_users_fetch_raises_on_not_found
    skip_on_windows("Backend not implemented for Windows yet")

    assert_raise(EtcUtils::NotFoundError) do
      EtcUtils.users.fetch("nonexistent_user_xyz_123")
    end
  end

  def test_users_get_returns_nil_on_not_found
    skip_on_windows("Backend not implemented for Windows yet")

    user = EtcUtils.users.get("nonexistent_user_xyz_123")
    assert_nil user
  end

  def test_users_exists
    skip_on_windows("Backend not implemented for Windows yet")

    assert EtcUtils.users.exists?("root")
    refute EtcUtils.users.exists?("nonexistent_user_xyz_123")
  end

  def test_groups_returns_collection
    skip_on_windows("Backend not implemented for Windows yet")

    groups = EtcUtils.groups
    assert_kind_of EtcUtils::GroupCollection, groups
  end

  def test_groups_each_yields_group_objects
    skip_on_windows("Backend not implemented for Windows yet")

    EtcUtils.groups.take(3).each do |group|
      assert_kind_of EtcUtils::Group, group
      assert_respond_to group, :name
      assert_respond_to group, :gid
      assert_respond_to group, :members
    end
  end

  def test_groups_get_by_name
    skip_on_windows("Backend not implemented for Windows yet")

    # wheel exists on macOS, root exists on Linux
    group_name = MACOS ? "wheel" : "root"
    group = EtcUtils.groups.get(group_name)

    assert_not_nil group
    assert_equal group_name, group.name
    assert_equal 0, group.gid
  end

  def test_groups_get_by_gid
    skip_on_windows("Backend not implemented for Windows yet")

    group = EtcUtils.groups.get(0)
    assert_not_nil group
    assert_equal 0, group.gid
  end

  def test_capabilities_structure
    caps = EtcUtils.capabilities

    assert_kind_of Hash, caps
    assert caps.key?(:os)
    assert caps.key?(:users)
    assert caps.key?(:groups)
    assert caps.key?(:shadow)
    assert caps.key?(:gshadow)
    assert caps.key?(:locking)
  end

  def test_supports_users
    assert EtcUtils.supports?(:users)
  end

  def test_supports_groups
    assert EtcUtils.supports?(:groups)
  end

  def test_supports_shadow_platform_dependent
    if LINUX
      assert EtcUtils.supports?(:shadow)
    elsif MACOS
      refute EtcUtils.supports?(:shadow)
    end
  end

  def test_eu_alias_exists
    assert_equal EtcUtils, EU
  end

  def test_user_to_entry_round_trip
    original = "testuser:x:1000:1000:Test User:/home/testuser:/bin/bash"
    user = EtcUtils::User.parse(original)
    assert_equal original, user.to_entry
  end

  def test_group_to_entry_round_trip
    original = "testgroup:x:1000:alice,bob"
    group = EtcUtils::Group.parse(original)
    assert_equal original, group.to_entry
  end

  def test_version_is_2_0_0
    assert_equal "2.0.0", EtcUtils::VERSION
  end
end
