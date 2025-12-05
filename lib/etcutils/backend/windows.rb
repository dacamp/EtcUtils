# frozen_string_literal: true

module EtcUtils
  module Backend
    # Windows backend implementation
    #
    # This backend provides read-only access to Windows user and group
    # databases using the Win32 API via FFI. It reads from the local
    # Security Accounts Manager (SAM) database.
    #
    # Features:
    #   - User enumeration and lookup
    #   - Group enumeration and lookup
    #   - SID (Security Identifier) exposure
    #
    # Limitations:
    #   - Write operations are not supported
    #   - No shadow/gshadow equivalent (Windows uses different auth)
    #   - No file locking (not applicable)
    #
    # @note This backend requires the 'ffi' gem to be installed on Windows
    #
    class Windows < Base
      def initialize
        @ffi_available = false
        @user_cache = nil
        @group_cache = nil
      end

      # Iterate all local users
      #
      # @yield [Hash] user attributes hash
      # @return [Enumerator] if no block given
      def each_user
        return to_enum(:each_user) unless block_given?

        enumerate_users.each do |user|
          yield user
        end
      end

      # Iterate all local groups
      #
      # @yield [Hash] group attributes hash
      # @return [Enumerator] if no block given
      def each_group
        return to_enum(:each_group) unless block_given?

        enumerate_groups.each do |group|
          yield group
        end
      end

      # Find user by name or (pseudo) UID
      #
      # @param identifier [String, Integer] username or UID
      # @return [Hash, nil] user attributes or nil if not found
      def find_user(identifier)
        if identifier.is_a?(Integer)
          each_user do |attrs|
            return attrs if attrs[:uid] == identifier
          end
          nil
        else
          get_user_info(identifier.to_s)
        end
      end

      # Find group by name or (pseudo) GID
      #
      # @param identifier [String, Integer] group name or GID
      # @return [Hash, nil] group attributes or nil if not found
      def find_group(identifier)
        if identifier.is_a?(Integer)
          each_group do |attrs|
            return attrs if attrs[:gid] == identifier
          end
          nil
        else
          get_group_info(identifier.to_s)
        end
      end

      # Return platform identifier
      #
      # @return [Symbol] :windows
      def platform_name
        :windows
      end

      # Return platform capability hash
      #
      # @return [Hash] nested capability structure
      def capabilities
        {
          os: :windows,
          os_version: Platform.os_version,
          etcutils_version: VERSION,
          users: { read: true, write: false },
          groups: { read: true, write: false },
          shadow: { read: false, write: false },
          gshadow: { read: false, write: false },
          locking: false
        }
      end

      # Clear cached data
      #
      # @return [void]
      def clear_cache
        @user_cache = nil
        @group_cache = nil
      end

      private

      def ffi_available?
        @ffi_available
      end

      # Enumerate all local users
      # Returns empty array on non-Windows platforms
      def enumerate_users
        return [] unless ffi_available?
        []
      end

      # Get user information by name
      # Returns nil on non-Windows platforms
      def get_user_info(_username)
        return nil unless ffi_available?
        nil
      end

      # Enumerate all local groups
      # Returns empty array on non-Windows platforms
      def enumerate_groups
        return [] unless ffi_available?
        []
      end

      # Get group information by name
      # Returns nil on non-Windows platforms
      def get_group_info(_groupname)
        return nil unless ffi_available?
        nil
      end

      # Generate a pseudo-GID from group name
      def generate_gid(groupname)
        groupname.bytes.reduce(0) { |acc, b| (acc * 31 + b) & 0xFFFFFFFF }
      end
    end

    # Only attempt to register if we're actually on Windows
    # The full FFI-based implementation would go in a separate file
    # that's only loaded on Windows systems
    Registry.register(:windows, Windows.new) if Platform.os == :windows
  end
end

# Load Windows FFI implementation only on Windows
if EtcUtils::Platform.os == :windows
  begin
    require_relative "windows_ffi"
  rescue LoadError
    # FFI-based implementation not available
  end
end
