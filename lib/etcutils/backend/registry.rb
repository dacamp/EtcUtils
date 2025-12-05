# frozen_string_literal: true

module EtcUtils
  module Backend
    # Registry manages backend selection based on platform
    #
    # This module automatically detects the current platform and provides
    # the appropriate backend implementation. Backends can also be
    # registered manually for testing or custom implementations.
    #
    # @example Get the current backend
    #   backend = EtcUtils::Backend::Registry.current
    #
    # @example Register a custom backend
    #   EtcUtils::Backend::Registry.register(:custom, MyBackend.new)
    #
    module Registry
      class << self
        # Returns the backend for the current platform
        #
        # @return [Backend::Base] the platform-appropriate backend
        # @raise [UnsupportedError] if no backend available for platform
        def current
          @current ||= backend_for(Platform.os)
        end

        # Returns a backend for the specified platform
        #
        # @param platform [Symbol] :linux, :darwin, :windows, or :unknown
        # @return [Backend::Base] the backend for that platform
        # @raise [UnsupportedError] if no backend registered for platform
        def backend_for(platform)
          backend = registered_backends[platform]
          return backend if backend

          raise UnsupportedError.new(
            operation: "platform support",
            platform: platform
          )
        end

        # Register a backend for a platform
        #
        # @param platform [Symbol] platform identifier
        # @param backend [Backend::Base] backend instance
        # @return [void]
        def register(platform, backend)
          registered_backends[platform] = backend
        end

        # Unregister a backend (primarily for testing)
        #
        # @param platform [Symbol] platform identifier
        # @return [void]
        def unregister(platform)
          registered_backends.delete(platform)
        end

        # Reset registry to initial state (for testing)
        #
        # @return [void]
        def reset!
          @current = nil
          @registered_backends = nil
        end

        # List all registered platforms
        #
        # @return [Array<Symbol>] registered platform identifiers
        def registered_platforms
          registered_backends.keys
        end

        private

        def registered_backends
          @registered_backends ||= {}
        end
      end
    end
  end
end
