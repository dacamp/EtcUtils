# frozen_string_literal: true

module EtcUtils
  # Shadow represents a shadow password entry (from /etc/shadow, Linux only)
  #
  # Fields:
  #   name          - login name
  #   passwd        - encrypted password
  #   last_change   - days since epoch of last password change
  #   min_days      - minimum days between password changes
  #   max_days      - maximum days between password changes
  #   warn_days     - days before expiry to warn user
  #   inactive_days - days after expiry until account disabled
  #   expire_date   - days since epoch when account expires
  #   reserved      - reserved field
  #
  Shadow = Struct.new(
    :name,
    :passwd,
    :last_change,
    :min_days,
    :max_days,
    :warn_days,
    :inactive_days,
    :expire_date,
    :reserved,
    keyword_init: true
  ) do
    # Parse a shadow-format entry string into a Shadow object
    #
    # @param entry [String] shadow entry in colon-separated format
    # @return [Shadow] parsed shadow object
    # @raise [ValidationError] if entry is malformed
    def self.parse(entry)
      raise ValidationError.new("Cannot parse nil entry", field: :entry) if entry.nil?

      parts = entry.chomp.split(":", -1)

      # Format: name:passwd:last_change:min:max:warn:inactive:expire:reserved
      if parts.length >= 9
        new(
          name: parts[0],
          passwd: parts[1],
          last_change: parse_int(parts[2]),
          min_days: parse_int(parts[3]),
          max_days: parse_int(parts[4]),
          warn_days: parse_int(parts[5]),
          inactive_days: parse_int(parts[6]),
          expire_date: parse_int(parts[7]),
          reserved: parts[8].empty? ? nil : parts[8]
        )
      else
        raise ValidationError.new(
          "Invalid shadow entry: expected at least 9 fields, got #{parts.length}",
          field: :entry,
          value: entry
        )
      end
    end

    # Convert to shadow-format entry string
    #
    # @return [String] colon-separated shadow entry
    def to_entry
      fields = [
        name,
        passwd,
        format_int(last_change),
        format_int(min_days),
        format_int(max_days),
        format_int(warn_days),
        format_int(inactive_days),
        format_int(expire_date),
        reserved || ""
      ]
      fields.join(":")
    end

    # Check if the password is locked (starts with ! or *)
    #
    # @return [Boolean] true if account is locked
    def locked?
      passwd&.start_with?("!") || passwd == "*"
    end

    # Check if the password is expired based on max_days
    #
    # @return [Boolean, nil] true if expired, nil if cannot determine
    def expired?
      return nil unless last_change && max_days
      return false if max_days == 99999 # Effectively never expires

      days_since_epoch = (Time.now.to_i / 86400)
      (last_change + max_days) < days_since_epoch
    end

    # Convert to hash, optionally excluding nil values
    #
    # @param compact [Boolean] if true, exclude nil values
    # @return [Hash] shadow attributes
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

    def format_int(val)
      val.nil? ? "" : val.to_s
    end
  end
end
