# frozen_string_literal: true

module EtcUtils
  # Base error class for all EtcUtils exceptions
  class Error < StandardError; end

  # Raised when a user or group is not found
  class NotFoundError < Error
    attr_reader :entity_type, :identifier

    def initialize(message = nil, entity_type: nil, identifier: nil)
      @entity_type = entity_type
      @identifier = identifier
      super(message || build_message)
    end

    private

    def build_message
      if entity_type && identifier
        "#{entity_type.to_s.capitalize} not found: #{identifier.inspect}"
      else
        "Entity not found"
      end
    end
  end

  # Raised when an operation requires elevated privileges
  class PermissionError < Error
    attr_reader :path, :operation, :required_privilege

    def initialize(message = nil, path: nil, operation: nil, required_privilege: nil)
      @path = path
      @operation = operation
      @required_privilege = required_privilege
      super(message || build_message)
    end

    # Returns platform-specific hint for resolving the permission issue
    #
    # @param platform [Symbol, nil] platform to get hint for (defaults to current)
    # @return [String] hint message
    def platform_hint(platform = nil)
      platform ||= EtcUtils::Platform.os
      case platform
      when :linux
        "Try running with sudo or as root."
      when :darwin
        "Try running with sudo. For user management, consider using dscl or System Preferences."
      when :windows
        "Run as Administrator. Note: EtcUtils has limited write support on Windows."
      else
        "Check your permissions."
      end
    end

    private

    def build_message
      base = "Permission denied"
      base += " #{operation}" if operation
      base += " #{path}" if path
      "#{base}. #{platform_hint}"
    end
  end

  # Raised when an operation is not supported on the current platform
  class UnsupportedError < Error
    attr_reader :operation, :platform

    def initialize(message = nil, operation: nil, platform: nil)
      @operation = operation
      @platform = platform || EtcUtils::Platform.os
      super(message || build_message)
    end

    private

    def build_message
      if operation
        "#{operation} is not supported on #{platform}"
      else
        "Operation not supported on #{platform}"
      end
    end
  end

  # Raised when file lock cannot be acquired
  class LockError < Error
    attr_reader :timeout, :path

    def initialize(message = nil, timeout: nil, path: nil)
      @timeout = timeout
      @path = path
      super(message || build_message)
    end

    private

    def build_message
      msg = "Could not acquire lock"
      msg += " on #{path}" if path
      msg += " (timeout: #{timeout}s)" if timeout
      msg
    end
  end

  # Raised when input validation fails
  class ValidationError < Error
    attr_reader :field, :value, :errors

    def initialize(message = nil, field: nil, value: nil, errors: nil)
      @field = field
      @value = value
      @errors = errors || []
      super(message || build_message)
    end

    private

    def build_message
      if field && value
        "Validation failed for #{field}: #{value.inspect}"
      elsif errors.any?
        "Validation failed: #{errors.join(', ')}"
      else
        "Validation failed"
      end
    end
  end

  # Raised when a file was modified by another process during write
  class ConcurrentModificationError < Error
    attr_reader :path

    def initialize(message = nil, path: nil)
      @path = path
      super(message || build_message)
    end

    private

    def build_message
      if path
        "File #{path} was modified by another process during write operation"
      else
        "File was modified by another process during write operation"
      end
    end
  end
end
