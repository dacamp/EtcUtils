# frozen_string_literal: true

module EtcUtils
  module Backend
    # Base class defining the interface all platform backends must implement
    #
    # Backends handle the actual system calls for reading and writing user/group data.
    # Each platform (Linux, macOS, Windows) implements its own backend class.
    #
    # Required methods:
    #   - each_user, each_group: iterate entries
    #   - find_user, find_group: lookup by name or ID
    #   - platform_name: return :linux, :darwin, or :windows
    #   - capabilities: return capability hash
    #
    # Optional methods (raise UnsupportedError by default):
    #   - each_shadow, each_gshadow, find_shadow, find_gshadow
    #   - write_passwd, write_group, write_shadow, write_gshadow
    #   - with_lock
    #
    class Base
      # Iterate all users from the system database
      #
      # @yield [Hash] user attributes hash
      # @return [Enumerator] if no block given
      def each_user
        raise NotImplementedError, "#{self.class}#each_user must be implemented"
      end

      # Iterate all groups from the system database
      #
      # @yield [Hash] group attributes hash
      # @return [Enumerator] if no block given
      def each_group
        raise NotImplementedError, "#{self.class}#each_group must be implemented"
      end

      # Find user by name or UID
      #
      # @param identifier [String, Integer] username or UID
      # @return [Hash, nil] user attributes or nil if not found
      def find_user(identifier)
        raise NotImplementedError, "#{self.class}#find_user must be implemented"
      end

      # Find group by name or GID
      #
      # @param identifier [String, Integer] group name or GID
      # @return [Hash, nil] group attributes or nil if not found
      def find_group(identifier)
        raise NotImplementedError, "#{self.class}#find_group must be implemented"
      end

      # Iterate all shadow entries (Linux only by default)
      #
      # @yield [Hash] shadow attributes hash
      # @return [Enumerator] if no block given
      # @raise [UnsupportedError] if not supported on platform
      # @raise [PermissionError] if insufficient permissions
      def each_shadow
        raise UnsupportedError.new(operation: "shadow access", platform: platform_name)
      end

      # Iterate all gshadow entries (Linux only by default)
      #
      # @yield [Hash] gshadow attributes hash
      # @return [Enumerator] if no block given
      # @raise [UnsupportedError] if not supported on platform
      # @raise [PermissionError] if insufficient permissions
      def each_gshadow
        raise UnsupportedError.new(operation: "gshadow access", platform: platform_name)
      end

      # Find shadow entry by username
      #
      # @param name [String] username
      # @return [Hash, nil] shadow attributes or nil
      # @raise [UnsupportedError] if not supported on platform
      def find_shadow(name)
        raise UnsupportedError.new(operation: "shadow access", platform: platform_name)
      end

      # Find gshadow entry by group name
      #
      # @param name [String] group name
      # @return [Hash, nil] gshadow attributes or nil
      # @raise [UnsupportedError] if not supported on platform
      def find_gshadow(name)
        raise UnsupportedError.new(operation: "gshadow access", platform: platform_name)
      end

      # Write passwd entries atomically
      #
      # @param entries [Array<Hash>] user entries to write
      # @param backup [Boolean] create backup file first
      # @param dry_run [Boolean] validate only, don't write
      # @return [DryRunResult, nil] result if dry_run, nil otherwise
      # @raise [UnsupportedError] if writes not supported
      # @raise [PermissionError] if insufficient permissions
      # @raise [LockError] if lock acquisition fails
      def write_passwd(entries, backup: true, dry_run: false)
        raise UnsupportedError.new(operation: "passwd writes", platform: platform_name)
      end

      # Write group entries atomically
      #
      # @param entries [Array<Hash>] group entries to write
      # @param backup [Boolean] create backup file first
      # @param dry_run [Boolean] validate only, don't write
      # @return [DryRunResult, nil] result if dry_run, nil otherwise
      # @raise [UnsupportedError] if writes not supported
      def write_group(entries, backup: true, dry_run: false)
        raise UnsupportedError.new(operation: "group writes", platform: platform_name)
      end

      # Write shadow entries atomically
      #
      # @param entries [Array<Hash>] shadow entries to write
      # @param backup [Boolean] create backup file first
      # @param dry_run [Boolean] validate only, don't write
      # @return [DryRunResult, nil] result if dry_run, nil otherwise
      # @raise [UnsupportedError] if writes not supported
      def write_shadow(entries, backup: true, dry_run: false)
        raise UnsupportedError.new(operation: "shadow writes", platform: platform_name)
      end

      # Write gshadow entries atomically
      #
      # @param entries [Array<Hash>] gshadow entries to write
      # @param backup [Boolean] create backup file first
      # @param dry_run [Boolean] validate only, don't write
      # @return [DryRunResult, nil] result if dry_run, nil otherwise
      # @raise [UnsupportedError] if writes not supported
      def write_gshadow(entries, backup: true, dry_run: false)
        raise UnsupportedError.new(operation: "gshadow writes", platform: platform_name)
      end

      # Execute block with system-wide password file lock
      #
      # @param timeout [Integer] seconds to wait for lock
      # @yield executes block with lock held
      # @return block result
      # @raise [LockError] if lock cannot be acquired
      # @raise [UnsupportedError] if locking not supported
      def with_lock(timeout: 15)
        raise UnsupportedError.new(operation: "file locking", platform: platform_name)
      end

      # Check if currently holding the lock
      #
      # @return [Boolean] true if locked
      def locked?
        false
      end

      # Return platform identifier
      #
      # @return [Symbol] :linux, :darwin, :windows, or :unknown
      def platform_name
        raise NotImplementedError, "#{self.class}#platform_name must be implemented"
      end

      # Return platform capability hash
      #
      # @return [Hash] nested capability structure
      def capabilities
        raise NotImplementedError, "#{self.class}#capabilities must be implemented"
      end

      # Check if a specific feature is supported
      #
      # @param feature [Symbol] feature to check
      # @return [Boolean] true if supported
      def supports?(feature)
        caps = capabilities
        case feature
        when :users_read then caps[:users][:read]
        when :users_write then caps[:users][:write]
        when :groups_read then caps[:groups][:read]
        when :groups_write then caps[:groups][:write]
        when :shadow_read, :shadow then caps[:shadow][:read]
        when :shadow_write then caps[:shadow][:write]
        when :gshadow_read, :gshadow then caps[:gshadow][:read]
        when :gshadow_write then caps[:gshadow][:write]
        when :locking then caps[:locking]
        else false
        end
      end
    end
  end
end
