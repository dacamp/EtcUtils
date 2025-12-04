# frozen_string_literal: true

# EtcUtils - Cross-platform user and group database management
#
# EtcUtils provides a Ruby-idiomatic API for reading (and on Linux, writing)
# system user and group databases across Linux, macOS, and Windows.
#
# @example List all users
#   EtcUtils.users.each { |user| puts user.name }
#
# @example Find a user
#   user = EtcUtils.users.get("root")
#   user = EtcUtils.users[0]  # by UID
#
# @example Check platform capabilities
#   if EtcUtils::Platform.supports?(:shadow)
#     # Access shadow entries
#   end
#
# @example Write users (Linux only, requires root)
#   EtcUtils.write_passwd(entries, backup: true)
#
module EtcUtils
  class << self
    # Returns a UserCollection for iterating and querying users
    #
    # @return [UserCollection] collection of system users
    #
    # @example
    #   EtcUtils.users.each { |u| puts u.name }
    #   EtcUtils.users.get("root")
    def users
      @users ||= UserCollection.new
    end

    # Returns a GroupCollection for iterating and querying groups
    #
    # @return [GroupCollection] collection of system groups
    #
    # @example
    #   EtcUtils.groups.each { |g| puts g.name }
    #   EtcUtils.groups.get("wheel")
    def groups
      @groups ||= GroupCollection.new
    end

    # Returns platform capability information
    #
    # @return [Hash] nested capability structure
    # @see Platform.capabilities
    def capabilities
      Platform.capabilities
    end

    # Check if a specific feature is supported on this platform
    #
    # @param feature [Symbol] feature to check
    # @return [Boolean] true if supported
    # @see Platform.supports?
    def supports?(feature)
      Platform.supports?(feature)
    end

    # Execute a block with system-wide password file lock
    #
    # On Linux, acquires the system password file lock before executing the
    # block. On other platforms, raises UnsupportedError.
    #
    # @param timeout [Integer] seconds to wait for lock (default 15)
    # @yield executes block with lock held
    # @return block result
    # @raise [LockError] if lock cannot be acquired
    # @raise [UnsupportedError] if locking not supported on platform
    #
    # @example
    #   EtcUtils.with_lock do
    #     # Safe to modify user database files
    #   end
    def with_lock(timeout: 15, &block)
      Backend::Registry.current.with_lock(timeout: timeout, &block)
    end

    # Check if the password file lock is currently held
    #
    # @return [Boolean] true if locked
    def locked?
      Backend::Registry.current.locked?
    end

    # Write passwd entries atomically
    #
    # @param entries [Array<User>] user entries to write
    # @param backup [Boolean] create backup file first (default: true)
    # @param dry_run [Boolean] validate only, don't write (default: false)
    # @return [DryRunResult, nil] result if dry_run, nil otherwise
    # @raise [UnsupportedError] if writes not supported on platform
    # @raise [PermissionError] if insufficient permissions
    # @raise [LockError] if lock acquisition fails
    def write_passwd(entries, backup: true, dry_run: false)
      Backend::Registry.current.write_passwd(entries, backup: backup, dry_run: dry_run)
    end

    # Write group entries atomically
    #
    # @param entries [Array<Group>] group entries to write
    # @param backup [Boolean] create backup file first (default: true)
    # @param dry_run [Boolean] validate only, don't write (default: false)
    # @return [DryRunResult, nil] result if dry_run, nil otherwise
    # @raise [UnsupportedError] if writes not supported on platform
    def write_group(entries, backup: true, dry_run: false)
      Backend::Registry.current.write_group(entries, backup: backup, dry_run: dry_run)
    end

    # Write shadow entries atomically (Linux only)
    #
    # @param entries [Array<Shadow>] shadow entries to write
    # @param backup [Boolean] create backup file first (default: true)
    # @param dry_run [Boolean] validate only, don't write (default: false)
    # @return [DryRunResult, nil] result if dry_run, nil otherwise
    # @raise [UnsupportedError] if writes not supported on platform
    def write_shadow(entries, backup: true, dry_run: false)
      Backend::Registry.current.write_shadow(entries, backup: backup, dry_run: dry_run)
    end

    # Write gshadow entries atomically (Linux only)
    #
    # @param entries [Array<GShadow>] gshadow entries to write
    # @param backup [Boolean] create backup file first (default: true)
    # @param dry_run [Boolean] validate only, don't write (default: false)
    # @return [DryRunResult, nil] result if dry_run, nil otherwise
    # @raise [UnsupportedError] if writes not supported on platform
    def write_gshadow(entries, backup: true, dry_run: false)
      Backend::Registry.current.write_gshadow(entries, backup: backup, dry_run: dry_run)
    end

    # Reset all cached state (primarily for testing)
    #
    # @return [void]
    def reset!
      @users = nil
      @groups = nil
      Platform.reset!
      Backend::Registry.reset!
    end
  end
end

# Load version first
require_relative "etcutils/version"

# Load error classes
require_relative "etcutils/errors"

# Load platform detection
require_relative "etcutils/platform"

# Load value objects
require_relative "etcutils/user"
require_relative "etcutils/group"
require_relative "etcutils/shadow"
require_relative "etcutils/gshadow"

# Load dry run result
require_relative "etcutils/dry_run_result"

# Load backend infrastructure
require_relative "etcutils/backend/base"
require_relative "etcutils/backend/registry"

# Load collections
require_relative "etcutils/users"
require_relative "etcutils/groups"

# Load platform-specific backends based on current OS
case EtcUtils::Platform.os
when :linux
  require_relative "etcutils/backend/linux" if File.exist?(File.join(__dir__, "etcutils/backend/linux.rb"))
when :darwin
  require_relative "etcutils/backend/darwin" if File.exist?(File.join(__dir__, "etcutils/backend/darwin.rb"))
when :windows
  require_relative "etcutils/backend/windows" if File.exist?(File.join(__dir__, "etcutils/backend/windows.rb"))
end

# Shorthand alias
EU = EtcUtils
