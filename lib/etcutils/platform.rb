# frozen_string_literal: true

module EtcUtils
  # Platform provides runtime detection of OS and capabilities
  #
  # This module allows code to query what operations are supported
  # on the current platform before attempting them.
  #
  # @example Check platform
  #   EtcUtils::Platform.os # => :linux, :darwin, or :windows
  #
  # @example Check capability
  #   if EtcUtils::Platform.supports?(:shadow)
  #     # Access shadow entries
  #   end
  #
  # @example Get full capabilities
  #   caps = EtcUtils::Platform.capabilities
  #   caps[:users][:write] # => true on Linux, false on macOS/Windows
  #
  module Platform
    class << self
      # Returns the current operating system identifier
      #
      # @return [Symbol] :linux, :darwin, :windows, or :unknown
      def os
        @os ||= detect_os
      end

      # Returns the OS version string
      #
      # @return [String] version string (kernel version on Linux/macOS, build on Windows)
      def os_version
        @os_version ||= detect_os_version
      end

      # Check if a specific feature is supported
      #
      # Supported feature symbols:
      #   :users, :groups - always true (read)
      #   :shadow, :gshadow - Linux only
      #   :users_write, :groups_write - Linux only
      #   :shadow_write, :gshadow_write - Linux only
      #   :locking - Linux only
      #
      # @param feature [Symbol] feature to check
      # @return [Boolean] true if supported
      def supports?(feature)
        caps = capabilities

        case feature
        when :users, :groups
          true # Read always supported
        when :shadow
          caps[:shadow][:read]
        when :gshadow
          caps[:gshadow][:read]
        when :users_write
          caps[:users][:write]
        when :groups_write
          caps[:groups][:write]
        when :shadow_write
          caps[:shadow][:write]
        when :gshadow_write
          caps[:gshadow][:write]
        when :locking
          caps[:locking]
        else
          false
        end
      end

      # Returns a hash of all platform capabilities
      #
      # @return [Hash] nested capability structure
      def capabilities
        @capabilities ||= build_capabilities
      end

      # Force capability detection refresh (useful for testing)
      #
      # @return [void]
      def reset!
        @os = nil
        @os_version = nil
        @capabilities = nil
      end

      private

      def detect_os
        case RUBY_PLATFORM
        when /linux/i
          :linux
        when /darwin/i
          :darwin
        when /mswin|mingw|cygwin/i
          :windows
        else
          :unknown
        end
      end

      def detect_os_version
        case os
        when :linux
          `uname -r`.strip rescue "unknown"
        when :darwin
          `uname -r`.strip rescue "unknown"
        when :windows
          # Windows version from environment or registry
          ENV["OS_VERSION"] || `ver`.strip.match(/\d+\.\d+\.\d+/)&.to_s || "unknown"
        else
          "unknown"
        end
      end

      def build_capabilities
        case os
        when :linux
          build_linux_capabilities
        when :darwin
          build_darwin_capabilities
        when :windows
          build_windows_capabilities
        else
          build_unknown_capabilities
        end
      end

      def build_linux_capabilities
        {
          os: :linux,
          os_version: os_version,
          etcutils_version: EtcUtils::VERSION,
          users: { read: true, write: true },
          groups: { read: true, write: true },
          shadow: { read: true, write: true },
          gshadow: { read: true, write: true },
          locking: true
        }
      end

      def build_darwin_capabilities
        {
          os: :darwin,
          os_version: os_version,
          etcutils_version: EtcUtils::VERSION,
          users: { read: true, write: false },
          groups: { read: true, write: false },
          shadow: { read: false, write: false },
          gshadow: { read: false, write: false },
          locking: false
        }
      end

      def build_windows_capabilities
        {
          os: :windows,
          os_version: os_version,
          etcutils_version: EtcUtils::VERSION,
          users: { read: true, write: false },
          groups: { read: true, write: false },
          shadow: { read: false, write: false },
          gshadow: { read: false, write: false },
          locking: false
        }
      end

      def build_unknown_capabilities
        {
          os: :unknown,
          os_version: os_version,
          etcutils_version: EtcUtils::VERSION,
          users: { read: false, write: false },
          groups: { read: false, write: false },
          shadow: { read: false, write: false },
          gshadow: { read: false, write: false },
          locking: false
        }
      end
    end
  end
end
