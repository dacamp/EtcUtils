# frozen_string_literal: true

module EtcUtils
  # User represents a user account entry (from /etc/passwd or equivalent)
  #
  # Common fields (all platforms):
  #   name   - login name
  #   passwd - password placeholder (usually 'x' on modern systems)
  #   uid    - numeric user ID
  #   gid    - numeric primary group ID
  #   gecos  - user information (full name, etc.)
  #   dir    - home directory path
  #   shell  - login shell path
  #
  # macOS-specific fields (nil on other platforms):
  #   pw_change - last password change time
  #   pw_expire - account expiration time
  #   pw_class  - login class
  #
  # Windows-specific fields (nil on other platforms):
  #   sid - Security Identifier string
  #
  User = Struct.new(
    :name,
    :passwd,
    :uid,
    :gid,
    :gecos,
    :dir,
    :shell,
    :pw_change,
    :pw_expire,
    :pw_class,
    :sid,
    keyword_init: true
  ) do
    # Alias for home directory
    alias home dir

    # Parse a passwd-format entry string into a User object
    #
    # @param entry [String] passwd entry in colon-separated format
    # @return [User] parsed user object
    # @raise [ValidationError] if entry is malformed
    def self.parse(entry)
      raise ValidationError.new("Cannot parse nil entry", field: :entry) if entry.nil?

      parts = entry.chomp.split(":", -1)

      # Standard format: name:passwd:uid:gid:gecos:dir:shell (7 fields)
      # macOS format: name:passwd:uid:gid:class:change:expire:gecos:dir:shell (10 fields)
      if parts.length >= 10
        # macOS extended format
        new(
          name: parts[0],
          passwd: parts[1],
          uid: parse_int(parts[2]),
          gid: parse_int(parts[3]),
          pw_class: parts[4].empty? ? nil : parts[4],
          pw_change: parse_int(parts[5]),
          pw_expire: parse_int(parts[6]),
          gecos: parts[7],
          dir: parts[8],
          shell: parts[9]
        )
      elsif parts.length >= 7
        # Standard POSIX format
        new(
          name: parts[0],
          passwd: parts[1],
          uid: parse_int(parts[2]),
          gid: parse_int(parts[3]),
          gecos: parts[4],
          dir: parts[5],
          shell: parts[6]
        )
      else
        raise ValidationError.new(
          "Invalid passwd entry: expected at least 7 fields, got #{parts.length}",
          field: :entry,
          value: entry
        )
      end
    end

    # Convert to passwd-format entry string
    #
    # @return [String] colon-separated passwd entry
    def to_entry
      "#{name}:#{passwd}:#{uid}:#{gid}:#{gecos}:#{dir}:#{shell}"
    end

    # Returns hash of platform-specific fields for the current OS
    #
    # @return [Hash] platform-specific field values
    def platform_fields
      case EtcUtils::Platform.os
      when :windows
        { sid: sid }
      when :darwin
        { pw_change: pw_change, pw_expire: pw_expire, pw_class: pw_class }
      else
        {}
      end
    end

    # Convert to hash, optionally excluding nil values
    #
    # @param compact [Boolean] if true, exclude nil values
    # @return [Hash] user attributes
    def to_h(compact: false)
      hash = super()
      compact ? hash.compact : hash
    end

    private

    def self.parse_int(str)
      return nil if str.nil? || str.empty?
      Integer(str)
    rescue ArgumentError
      nil
    end
  end
end
