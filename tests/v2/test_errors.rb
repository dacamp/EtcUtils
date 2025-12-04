# frozen_string_literal: true

require_relative "test_helper"

class TestErrors < Test::Unit::TestCase
  def test_error_base_class
    assert EtcUtils::Error < StandardError
  end

  def test_not_found_error
    error = EtcUtils::NotFoundError.new("User not found", entity_type: :user, identifier: "nobody")

    assert_equal "User not found", error.message
    assert_equal :user, error.entity_type
    assert_equal "nobody", error.identifier
  end

  def test_not_found_error_without_optional_params
    error = EtcUtils::NotFoundError.new("Something not found")

    assert_equal "Something not found", error.message
    assert_nil error.entity_type
    assert_nil error.identifier
  end

  def test_permission_error
    error = EtcUtils::PermissionError.new(
      "Cannot read /etc/shadow",
      path: "/etc/shadow",
      operation: :read,
      required_privilege: :root
    )

    assert_equal "Cannot read /etc/shadow", error.message
    assert_equal "/etc/shadow", error.path
    assert_equal :read, error.operation
    assert_equal :root, error.required_privilege
  end

  def test_permission_error_platform_hint_linux
    error = EtcUtils::PermissionError.new(
      "Cannot read",
      path: "/etc/shadow",
      operation: :read,
      required_privilege: :root
    )

    hint = error.platform_hint(:linux)
    assert_match(/sudo/, hint)
    assert_match(/root/, hint)
  end

  def test_permission_error_platform_hint_darwin
    error = EtcUtils::PermissionError.new(
      "Cannot read",
      path: "/etc/shadow",
      operation: :read,
      required_privilege: :root
    )

    hint = error.platform_hint(:darwin)
    assert_match(/sudo/, hint)
    assert_match(/dscl/, hint)
  end

  def test_permission_error_platform_hint_windows
    error = EtcUtils::PermissionError.new(
      "Cannot read",
      path: "SAM",
      operation: :read,
      required_privilege: :administrator
    )

    hint = error.platform_hint(:windows)
    assert_match(/Administrator/i, hint)
  end

  def test_unsupported_error
    error = EtcUtils::UnsupportedError.new(operation: "shadow access", platform: :darwin)

    assert_match(/shadow access/, error.message)
    assert_match(/darwin/, error.message)
    assert_equal "shadow access", error.operation
    assert_equal :darwin, error.platform
  end

  def test_lock_error
    error = EtcUtils::LockError.new(
      "Could not acquire lock",
      timeout: 15,
      path: "/etc/.pwd.lock"
    )

    assert_equal "Could not acquire lock", error.message
    assert_equal 15, error.timeout
    assert_equal "/etc/.pwd.lock", error.path
  end

  def test_validation_error_single_field
    error = EtcUtils::ValidationError.new(
      "Invalid username",
      field: :name,
      value: "bad user"
    )

    assert_equal "Invalid username", error.message
    assert_equal :name, error.field
    assert_equal "bad user", error.value
    assert_empty error.errors
  end

  def test_validation_error_multiple_errors
    errors_hash = {
      name: ["cannot be blank", "must not contain spaces"],
      uid: ["must be positive"]
    }

    error = EtcUtils::ValidationError.new(
      "Validation failed",
      errors: errors_hash
    )

    assert_equal "Validation failed", error.message
    assert_equal errors_hash, error.errors
  end

  def test_concurrent_modification_error
    error = EtcUtils::ConcurrentModificationError.new(
      "File changed during operation",
      path: "/etc/passwd"
    )

    assert_equal "File changed during operation", error.message
    assert_equal "/etc/passwd", error.path
  end

  def test_error_inheritance
    assert EtcUtils::NotFoundError < EtcUtils::Error
    assert EtcUtils::PermissionError < EtcUtils::Error
    assert EtcUtils::UnsupportedError < EtcUtils::Error
    assert EtcUtils::LockError < EtcUtils::Error
    assert EtcUtils::ValidationError < EtcUtils::Error
    assert EtcUtils::ConcurrentModificationError < EtcUtils::Error
  end
end
