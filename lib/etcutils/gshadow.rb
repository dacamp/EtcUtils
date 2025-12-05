# frozen_string_literal: true

module EtcUtils
  # GShadow represents a group shadow entry (from /etc/gshadow, Linux only)
  #
  # Fields:
  #   name    - group name
  #   passwd  - encrypted group password
  #   admins  - array of group administrator usernames
  #   members - array of member usernames
  #
  GShadow = Struct.new(
    :name,
    :passwd,
    :admins,
    :members,
    keyword_init: true
  ) do
    # Parse a gshadow-format entry string into a GShadow object
    #
    # @param entry [String] gshadow entry in colon-separated format
    # @return [GShadow] parsed gshadow object
    # @raise [ValidationError] if entry is malformed
    def self.parse(entry)
      raise ValidationError.new("Cannot parse nil entry", field: :entry) if entry.nil?

      parts = entry.chomp.split(":", -1)

      # Format: name:passwd:admins:members
      if parts.length >= 4
        admins_str = parts[2] || ""
        members_str = parts[3] || ""

        new(
          name: parts[0],
          passwd: parts[1],
          admins: admins_str.empty? ? [] : admins_str.split(","),
          members: members_str.empty? ? [] : members_str.split(",")
        )
      else
        raise ValidationError.new(
          "Invalid gshadow entry: expected at least 4 fields, got #{parts.length}",
          field: :entry,
          value: entry
        )
      end
    end

    # Convert to gshadow-format entry string
    #
    # @return [String] colon-separated gshadow entry
    def to_entry
      admin_list = (admins || []).join(",")
      member_list = (members || []).join(",")
      "#{name}:#{passwd}:#{admin_list}:#{member_list}"
    end

    # Check if the password is locked (starts with ! or is *)
    #
    # @return [Boolean] true if group password is locked/disabled
    def locked?
      passwd&.start_with?("!") || passwd == "*" || passwd == "!"
    end

    # Convert to hash, optionally excluding nil values
    #
    # @param compact [Boolean] if true, exclude nil values
    # @return [Hash] gshadow attributes
    def to_h(compact: false)
      hash = super()
      compact ? hash.compact : hash
    end
  end
end
