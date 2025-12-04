# frozen_string_literal: true

require_relative "test_helper"

class TestUser < Test::Unit::TestCase
  def test_user_struct_fields
    user = EtcUtils::User.new(
      name: "testuser",
      passwd: "x",
      uid: 1000,
      gid: 1000,
      gecos: "Test User",
      dir: "/home/testuser",
      shell: "/bin/bash"
    )

    assert_equal "testuser", user.name
    assert_equal "x", user.passwd
    assert_equal 1000, user.uid
    assert_equal 1000, user.gid
    assert_equal "Test User", user.gecos
    assert_equal "/home/testuser", user.dir
    assert_equal "/bin/bash", user.shell
  end

  def test_user_home_alias
    user = EtcUtils::User.new(dir: "/home/test")
    assert_equal "/home/test", user.home
    assert_equal user.dir, user.home
  end

  def test_user_keyword_init
    user = EtcUtils::User.new(name: "alice", uid: 1001)
    assert_equal "alice", user.name
    assert_equal 1001, user.uid
    assert_nil user.passwd
  end

  def test_parse_passwd_entry
    entry = "root:x:0:0:root:/root:/bin/bash"
    user = EtcUtils::User.parse(entry)

    assert_equal "root", user.name
    assert_equal "x", user.passwd
    assert_equal 0, user.uid
    assert_equal 0, user.gid
    assert_equal "root", user.gecos
    assert_equal "/root", user.dir
    assert_equal "/bin/bash", user.shell
  end

  def test_parse_passwd_entry_with_empty_fields
    entry = "nobody:*:65534:65534:Nobody:/nonexistent:/usr/sbin/nologin"
    user = EtcUtils::User.parse(entry)

    assert_equal "nobody", user.name
    assert_equal "*", user.passwd
    assert_equal 65534, user.uid
    assert_equal 65534, user.gid
    assert_equal "Nobody", user.gecos
    assert_equal "/nonexistent", user.dir
    assert_equal "/usr/sbin/nologin", user.shell
  end

  def test_parse_passwd_entry_with_empty_gecos
    entry = "daemon:x:1:1::/usr/sbin:/usr/sbin/nologin"
    user = EtcUtils::User.parse(entry)

    assert_equal "daemon", user.name
    assert_equal "", user.gecos
  end

  def test_parse_nil_raises_validation_error
    assert_raise(EtcUtils::ValidationError) do
      EtcUtils::User.parse(nil)
    end
  end

  def test_parse_invalid_entry_raises_validation_error
    assert_raise(EtcUtils::ValidationError) do
      EtcUtils::User.parse("invalid:entry")
    end
  end

  def test_to_entry
    user = EtcUtils::User.new(
      name: "testuser",
      passwd: "x",
      uid: 1000,
      gid: 1000,
      gecos: "Test User",
      dir: "/home/testuser",
      shell: "/bin/bash"
    )

    expected = "testuser:x:1000:1000:Test User:/home/testuser:/bin/bash"
    assert_equal expected, user.to_entry
  end

  def test_to_entry_round_trip
    original = "root:x:0:0:root:/root:/bin/bash"
    user = EtcUtils::User.parse(original)
    assert_equal original, user.to_entry
  end

  def test_to_h
    user = EtcUtils::User.new(name: "test", uid: 1000)
    hash = user.to_h

    assert_kind_of Hash, hash
    assert_equal "test", hash[:name]
    assert_equal 1000, hash[:uid]
    assert hash.key?(:passwd) # nil values included by default
  end

  def test_to_h_compact
    user = EtcUtils::User.new(name: "test", uid: 1000)
    hash = user.to_h(compact: true)

    assert_equal "test", hash[:name]
    assert_equal 1000, hash[:uid]
    refute hash.key?(:passwd) # nil values excluded
    refute hash.key?(:gid)
  end

  def test_platform_fields_on_darwin
    skip_unless_macos

    user = EtcUtils::User.new(
      name: "test",
      pw_change: 0,
      pw_expire: 0,
      pw_class: ""
    )

    fields = user.platform_fields
    assert fields.key?(:pw_change)
    assert fields.key?(:pw_expire)
    assert fields.key?(:pw_class)
  end

  def test_platform_fields_on_linux
    skip_unless_linux

    user = EtcUtils::User.new(name: "test")
    fields = user.platform_fields

    assert_equal({}, fields)
  end

  def test_equality
    user1 = EtcUtils::User.new(name: "test", uid: 1000)
    user2 = EtcUtils::User.new(name: "test", uid: 1000)
    user3 = EtcUtils::User.new(name: "other", uid: 1001)

    assert_equal user1, user2
    refute_equal user1, user3
  end
end
