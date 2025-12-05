# frozen_string_literal: true

require_relative "test_helper"

class TestShadow < Test::Unit::TestCase
  def setup
    super
    skip_if_v1_extension("Shadow struct tests require v2 classes")
  end

  def test_shadow_struct_fields
    shadow = EtcUtils::Shadow.new(
      name: "testuser",
      passwd: "$6$hash",
      last_change: 19000,
      min_days: 0,
      max_days: 99999,
      warn_days: 7,
      inactive_days: nil,
      expire_date: nil,
      reserved: nil
    )

    assert_equal "testuser", shadow.name
    assert_equal "$6$hash", shadow.passwd
    assert_equal 19000, shadow.last_change
    assert_equal 0, shadow.min_days
    assert_equal 99999, shadow.max_days
    assert_equal 7, shadow.warn_days
    assert_nil shadow.inactive_days
    assert_nil shadow.expire_date
    assert_nil shadow.reserved
  end

  def test_shadow_keyword_init
    shadow = EtcUtils::Shadow.new(name: "test", passwd: "!")
    assert_equal "test", shadow.name
    assert_equal "!", shadow.passwd
    assert_nil shadow.last_change
  end

  def test_parse_shadow_entry
    entry = "root:$6$abc123:19000:0:99999:7:::"
    shadow = EtcUtils::Shadow.parse(entry)

    assert_equal "root", shadow.name
    assert_equal "$6$abc123", shadow.passwd
    assert_equal 19000, shadow.last_change
    assert_equal 0, shadow.min_days
    assert_equal 99999, shadow.max_days
    assert_equal 7, shadow.warn_days
    assert_nil shadow.inactive_days
    assert_nil shadow.expire_date
    assert_nil shadow.reserved
  end

  def test_parse_shadow_entry_with_all_fields
    entry = "user:$6$hash:19000:1:90:14:30:20000:reserved"
    shadow = EtcUtils::Shadow.parse(entry)

    assert_equal "user", shadow.name
    assert_equal "$6$hash", shadow.passwd
    assert_equal 19000, shadow.last_change
    assert_equal 1, shadow.min_days
    assert_equal 90, shadow.max_days
    assert_equal 14, shadow.warn_days
    assert_equal 30, shadow.inactive_days
    assert_equal 20000, shadow.expire_date
    assert_equal "reserved", shadow.reserved
  end

  def test_parse_shadow_locked_account
    entry = "locked:!$6$hash:19000:0:99999:7:::"
    shadow = EtcUtils::Shadow.parse(entry)

    assert shadow.locked?
  end

  def test_parse_shadow_disabled_account
    entry = "nologin:*:19000:0:99999:7:::"
    shadow = EtcUtils::Shadow.parse(entry)

    assert shadow.locked?
  end

  def test_parse_nil_raises_validation_error
    assert_raise(EtcUtils::ValidationError) do
      EtcUtils::Shadow.parse(nil)
    end
  end

  def test_parse_invalid_entry_raises_validation_error
    assert_raise(EtcUtils::ValidationError) do
      EtcUtils::Shadow.parse("too:few:fields")
    end
  end

  def test_to_entry
    shadow = EtcUtils::Shadow.new(
      name: "testuser",
      passwd: "$6$hash",
      last_change: 19000,
      min_days: 0,
      max_days: 99999,
      warn_days: 7,
      inactive_days: nil,
      expire_date: nil,
      reserved: nil
    )

    expected = "testuser:$6$hash:19000:0:99999:7:::"
    assert_equal expected, shadow.to_entry
  end

  def test_to_entry_with_all_fields
    shadow = EtcUtils::Shadow.new(
      name: "user",
      passwd: "$6$hash",
      last_change: 19000,
      min_days: 1,
      max_days: 90,
      warn_days: 14,
      inactive_days: 30,
      expire_date: 20000,
      reserved: "flag"
    )

    expected = "user:$6$hash:19000:1:90:14:30:20000:flag"
    assert_equal expected, shadow.to_entry
  end

  def test_to_entry_round_trip
    original = "daemon:*:18000:0:99999:7:::"
    shadow = EtcUtils::Shadow.parse(original)
    assert_equal original, shadow.to_entry
  end

  def test_locked_with_exclamation
    shadow = EtcUtils::Shadow.new(passwd: "!$6$hash")
    assert shadow.locked?
  end

  def test_locked_with_asterisk
    shadow = EtcUtils::Shadow.new(passwd: "*")
    assert shadow.locked?
  end

  def test_locked_with_just_exclamation
    shadow = EtcUtils::Shadow.new(passwd: "!")
    assert shadow.locked?
  end

  def test_not_locked_with_valid_hash
    shadow = EtcUtils::Shadow.new(passwd: "$6$validhash")
    refute shadow.locked?
  end

  def test_expired_when_past_max_days
    # Set last_change to a date way in the past with short max_days
    past_epoch_days = 10000 # Way in the past
    shadow = EtcUtils::Shadow.new(
      passwd: "$6$hash",
      last_change: past_epoch_days,
      max_days: 30
    )

    assert shadow.expired?
  end

  def test_not_expired_when_within_max_days
    # Recent last_change with normal max_days
    today_days = Time.now.to_i / 86400
    shadow = EtcUtils::Shadow.new(
      passwd: "$6$hash",
      last_change: today_days,
      max_days: 99999
    )

    refute shadow.expired?
  end

  def test_not_expired_when_max_days_is_99999
    shadow = EtcUtils::Shadow.new(
      passwd: "$6$hash",
      last_change: 1,
      max_days: 99999
    )

    refute shadow.expired?
  end

  def test_expired_returns_nil_when_cannot_determine
    shadow = EtcUtils::Shadow.new(passwd: "$6$hash")
    assert_nil shadow.expired?

    shadow2 = EtcUtils::Shadow.new(passwd: "$6$hash", last_change: 19000)
    assert_nil shadow2.expired?
  end

  def test_to_h
    shadow = EtcUtils::Shadow.new(name: "test", passwd: "!", last_change: 19000)
    hash = shadow.to_h

    assert_kind_of Hash, hash
    assert_equal "test", hash[:name]
    assert_equal "!", hash[:passwd]
    assert_equal 19000, hash[:last_change]
  end

  def test_to_h_compact
    shadow = EtcUtils::Shadow.new(name: "test", passwd: "!")
    hash = shadow.to_h(compact: true)

    assert_equal "test", hash[:name]
    assert_equal "!", hash[:passwd]
    refute hash.key?(:last_change)
    refute hash.key?(:min_days)
  end

  def test_equality
    shadow1 = EtcUtils::Shadow.new(name: "test", passwd: "!")
    shadow2 = EtcUtils::Shadow.new(name: "test", passwd: "!")
    shadow3 = EtcUtils::Shadow.new(name: "other", passwd: "*")

    assert_equal shadow1, shadow2
    refute_equal shadow1, shadow3
  end
end
