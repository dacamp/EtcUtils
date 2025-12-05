# frozen_string_literal: true

module EtcUtils
  # Group represents a group entry (from /etc/group or equivalent)
  #
  # Common fields (all platforms):
  #   name    - group name
  #   passwd  - group password placeholder (usually 'x' or empty)
  #   gid     - numeric group ID
  #   members - array of member usernames
  #
  # Windows-specific fields (nil on other platforms):
  #   sid - Security Identifier string
  #
  Group = Struct.new(
    :name,
    :passwd,
    :gid,
    :members,
    :sid,
    keyword_init: true
  ) do
    # Parse a group-format entry string into a Group object
    #
    # @param entry [String] group entry in colon-separated format
    # @return [Group] parsed group object
    # @raise [ValidationError] if entry is malformed
    def self.parse(entry)
      raise ValidationError.new("Cannot parse nil entry", field: :entry) if entry.nil?

      parts = entry.chomp.split(":", -1)

      # Format: name:passwd:gid:member1,member2,...
      if parts.length >= 4
        members_str = parts[3] || ""
        members = members_str.empty? ? [] : members_str.split(",")

        new(
          name: parts[0],
          passwd: parts[1],
          gid: parse_int(parts[2]),
          members: members
        )
      else
        raise ValidationError.new(
          "Invalid group entry: expected at least 4 fields, got #{parts.length}",
          field: :entry,
          value: entry
        )
      end
    end

    # Convert to group-format entry string
    #
    # @return [String] colon-separated group entry
    def to_entry
      member_list = (members || []).join(",")
      "#{name}:#{passwd}:#{gid}:#{member_list}"
    end

    # Returns hash of platform-specific fields for the current OS
    #
    # @return [Hash] platform-specific field values
    def platform_fields
      case EtcUtils::Platform.os
      when :windows
        { sid: sid }
      else
        {}
      end
    end

    # Convert to hash, optionally excluding nil values
    #
    # @param compact [Boolean] if true, exclude nil values
    # @return [Hash] group attributes
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
