# frozen_string_literal: true

require_relative "test_helper"

class TestGShadow < Test::Unit::TestCase
  def test_gshadow_struct_fields
    gshadow = EtcUtils::GShadow.new(
      name: "wheel",
      passwd: "*",
      admins: %w[root],
      members: %w[alice bob]
    )

    assert_equal "wheel", gshadow.name
    assert_equal "*", gshadow.passwd
    assert_equal %w[root], gshadow.admins
    assert_equal %w[alice bob], gshadow.members
  end

  def test_gshadow_keyword_init
    gshadow = EtcUtils::GShadow.new(name: "sudo", passwd: "!")
    assert_equal "sudo", gshadow.name
    assert_equal "!", gshadow.passwd
    assert_nil gshadow.admins
    assert_nil gshadow.members
  end

  def test_parse_gshadow_entry
    entry = "wheel:*:root:alice,bob"
    gshadow = EtcUtils::GShadow.parse(entry)

    assert_equal "wheel", gshadow.name
    assert_equal "*", gshadow.passwd
    assert_equal %w[root], gshadow.admins
    assert_equal %w[alice bob], gshadow.members
  end

  def test_parse_gshadow_entry_empty_admins
    entry = "nogroup:!::user1,user2"
    gshadow = EtcUtils::GShadow.parse(entry)

    assert_equal "nogroup", gshadow.name
    assert_equal "!", gshadow.passwd
    assert_equal [], gshadow.admins
    assert_equal %w[user1 user2], gshadow.members
  end

  def test_parse_gshadow_entry_empty_members
    entry = "admin:*:root:"
    gshadow = EtcUtils::GShadow.parse(entry)

    assert_equal "admin", gshadow.name
    assert_equal %w[root], gshadow.admins
    assert_equal [], gshadow.members
  end

  def test_parse_gshadow_entry_empty_both
    entry = "empty:!::"
    gshadow = EtcUtils::GShadow.parse(entry)

    assert_equal "empty", gshadow.name
    assert_equal [], gshadow.admins
    assert_equal [], gshadow.members
  end

  def test_parse_nil_raises_validation_error
    assert_raise(EtcUtils::ValidationError) do
      EtcUtils::GShadow.parse(nil)
    end
  end

  def test_parse_invalid_entry_raises_validation_error
    assert_raise(EtcUtils::ValidationError) do
      EtcUtils::GShadow.parse("too:few")
    end
  end

  def test_to_entry
    gshadow = EtcUtils::GShadow.new(
      name: "wheel",
      passwd: "*",
      admins: %w[root],
      members: %w[alice bob]
    )

    expected = "wheel:*:root:alice,bob"
    assert_equal expected, gshadow.to_entry
  end

  def test_to_entry_empty_lists
    gshadow = EtcUtils::GShadow.new(
      name: "empty",
      passwd: "!",
      admins: [],
      members: []
    )

    expected = "empty:!::"
    assert_equal expected, gshadow.to_entry
  end

  def test_to_entry_nil_lists
    gshadow = EtcUtils::GShadow.new(
      name: "empty",
      passwd: "!",
      admins: nil,
      members: nil
    )

    expected = "empty:!::"
    assert_equal expected, gshadow.to_entry
  end

  def test_to_entry_round_trip
    original = "sudo:!:root,admin:alice,bob,charlie"
    gshadow = EtcUtils::GShadow.parse(original)
    assert_equal original, gshadow.to_entry
  end

  def test_locked_with_exclamation_prefix
    gshadow = EtcUtils::GShadow.new(passwd: "!$password")
    assert gshadow.locked?
  end

  def test_locked_with_just_exclamation
    gshadow = EtcUtils::GShadow.new(passwd: "!")
    assert gshadow.locked?
  end

  def test_locked_with_asterisk
    gshadow = EtcUtils::GShadow.new(passwd: "*")
    assert gshadow.locked?
  end

  def test_not_locked_with_password
    gshadow = EtcUtils::GShadow.new(passwd: "$6$hash")
    refute gshadow.locked?
  end

  def test_not_locked_with_empty_password
    gshadow = EtcUtils::GShadow.new(passwd: "")
    refute gshadow.locked?
  end

  def test_to_h
    gshadow = EtcUtils::GShadow.new(
      name: "wheel",
      passwd: "*",
      admins: %w[root],
      members: %w[alice]
    )
    hash = gshadow.to_h

    assert_kind_of Hash, hash
    assert_equal "wheel", hash[:name]
    assert_equal "*", hash[:passwd]
    assert_equal %w[root], hash[:admins]
    assert_equal %w[alice], hash[:members]
  end

  def test_to_h_compact
    gshadow = EtcUtils::GShadow.new(name: "test", passwd: "!")
    hash = gshadow.to_h(compact: true)

    assert_equal "test", hash[:name]
    assert_equal "!", hash[:passwd]
    refute hash.key?(:admins)
    refute hash.key?(:members)
  end

  def test_equality
    gs1 = EtcUtils::GShadow.new(name: "wheel", passwd: "*", admins: [], members: [])
    gs2 = EtcUtils::GShadow.new(name: "wheel", passwd: "*", admins: [], members: [])
    gs3 = EtcUtils::GShadow.new(name: "sudo", passwd: "!", admins: [], members: [])

    assert_equal gs1, gs2
    refute_equal gs1, gs3
  end
end
