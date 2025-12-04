# frozen_string_literal: true

require_relative "test_helper"

class TestGroup < Test::Unit::TestCase
  def test_group_struct_fields
    group = EtcUtils::Group.new(
      name: "testgroup",
      passwd: "x",
      gid: 1000,
      members: %w[alice bob]
    )

    assert_equal "testgroup", group.name
    assert_equal "x", group.passwd
    assert_equal 1000, group.gid
    assert_equal %w[alice bob], group.members
  end

  def test_group_keyword_init
    group = EtcUtils::Group.new(name: "wheel", gid: 0)
    assert_equal "wheel", group.name
    assert_equal 0, group.gid
    assert_nil group.members
  end

  def test_parse_group_entry
    entry = "wheel:x:0:root,admin"
    group = EtcUtils::Group.parse(entry)

    assert_equal "wheel", group.name
    assert_equal "x", group.passwd
    assert_equal 0, group.gid
    assert_equal %w[root admin], group.members
  end

  def test_parse_group_entry_empty_members
    entry = "nogroup:x:65534:"
    group = EtcUtils::Group.parse(entry)

    assert_equal "nogroup", group.name
    assert_equal 65534, group.gid
    assert_equal [], group.members
  end

  def test_parse_group_entry_single_member
    entry = "staff:*:20:admin"
    group = EtcUtils::Group.parse(entry)

    assert_equal "staff", group.name
    assert_equal %w[admin], group.members
  end

  def test_parse_nil_raises_validation_error
    assert_raise(EtcUtils::ValidationError) do
      EtcUtils::Group.parse(nil)
    end
  end

  def test_parse_invalid_entry_raises_validation_error
    assert_raise(EtcUtils::ValidationError) do
      EtcUtils::Group.parse("invalid")
    end
  end

  def test_to_entry
    group = EtcUtils::Group.new(
      name: "testgroup",
      passwd: "x",
      gid: 1000,
      members: %w[alice bob]
    )

    expected = "testgroup:x:1000:alice,bob"
    assert_equal expected, group.to_entry
  end

  def test_to_entry_empty_members
    group = EtcUtils::Group.new(
      name: "empty",
      passwd: "x",
      gid: 100,
      members: []
    )

    expected = "empty:x:100:"
    assert_equal expected, group.to_entry
  end

  def test_to_entry_nil_members
    group = EtcUtils::Group.new(
      name: "empty",
      passwd: "x",
      gid: 100,
      members: nil
    )

    expected = "empty:x:100:"
    assert_equal expected, group.to_entry
  end

  def test_to_entry_round_trip
    original = "sudo:x:27:alice,bob,charlie"
    group = EtcUtils::Group.parse(original)
    assert_equal original, group.to_entry
  end

  def test_to_h
    group = EtcUtils::Group.new(name: "test", gid: 1000, members: %w[alice])
    hash = group.to_h

    assert_kind_of Hash, hash
    assert_equal "test", hash[:name]
    assert_equal 1000, hash[:gid]
    assert_equal %w[alice], hash[:members]
  end

  def test_to_h_compact
    group = EtcUtils::Group.new(name: "test", gid: 1000)
    hash = group.to_h(compact: true)

    assert_equal "test", hash[:name]
    assert_equal 1000, hash[:gid]
    refute hash.key?(:passwd)
    refute hash.key?(:members)
  end

  def test_platform_fields_on_windows
    skip_on_linux
    skip_on_macos

    group = EtcUtils::Group.new(
      name: "Administrators",
      gid: 544,
      sid: "S-1-5-32-544"
    )

    fields = group.platform_fields
    assert_equal "S-1-5-32-544", fields[:sid]
  end

  def test_platform_fields_on_unix
    skip_on_windows

    group = EtcUtils::Group.new(name: "wheel", gid: 0)
    fields = group.platform_fields

    assert_equal({}, fields)
  end

  def test_equality
    group1 = EtcUtils::Group.new(name: "wheel", gid: 0, members: %w[root])
    group2 = EtcUtils::Group.new(name: "wheel", gid: 0, members: %w[root])
    group3 = EtcUtils::Group.new(name: "staff", gid: 20, members: [])

    assert_equal group1, group2
    refute_equal group1, group3
  end
end
