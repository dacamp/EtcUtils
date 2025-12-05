# frozen_string_literal: true

module EtcUtils
  module Backend
    # Darwin (macOS) backend implementation
    #
    # This backend provides read-only access to macOS user and group databases
    # using the dscl (Directory Service command line) utility.
    #
    # Features:
    #   - User enumeration and lookup
    #   - Group enumeration and lookup
    #   - macOS-specific fields (pw_change, pw_expire, pw_class)
    #
    # Limitations:
    #   - Write operations are not supported (use dscl or System Preferences)
    #   - No shadow/gshadow support (macOS uses different authentication)
    #   - No file locking (not applicable on macOS)
    #
    class Darwin < Base
      DSCL_PATH = "/usr/bin/dscl"
      LOCAL_NODE = "."

      def initialize
        @user_cache = nil
        @group_cache = nil
      end

      # Iterate all users from Directory Services
      #
      # @yield [Hash] user attributes hash
      # @return [Enumerator] if no block given
      def each_user
        return to_enum(:each_user) unless block_given?

        list_users.each do |username|
          attrs = read_user(username)
          yield attrs if attrs
        end
      end

      # Iterate all groups from Directory Services
      #
      # @yield [Hash] group attributes hash
      # @return [Enumerator] if no block given
      def each_group
        return to_enum(:each_group) unless block_given?

        list_groups.each do |groupname|
          attrs = read_group(groupname)
          yield attrs if attrs
        end
      end

      # Find user by name or UID
      #
      # @param identifier [String, Integer] username or UID
      # @return [Hash, nil] user attributes or nil if not found
      def find_user(identifier)
        if identifier.is_a?(Integer)
          find_user_by_uid(identifier)
        else
          read_user(identifier.to_s)
        end
      end

      # Find group by name or GID
      #
      # @param identifier [String, Integer] group name or GID
      # @return [Hash, nil] group attributes or nil if not found
      def find_group(identifier)
        if identifier.is_a?(Integer)
          find_group_by_gid(identifier)
        else
          read_group(identifier.to_s)
        end
      end

      # Return platform identifier
      #
      # @return [Symbol] :darwin
      def platform_name
        :darwin
      end

      # Return platform capability hash
      #
      # @return [Hash] nested capability structure
      def capabilities
        {
          os: :darwin,
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

      # List all usernames from Directory Services
      def list_users
        output = dscl_list("/Users")
        return [] unless output

        output.lines.map(&:strip).reject do |name|
          name.empty? || name.start_with?("_")
        end
      end

      # List all group names from Directory Services
      def list_groups
        output = dscl_list("/Groups")
        return [] unless output

        output.lines.map(&:strip).reject do |name|
          name.empty? || name.start_with?("_")
        end
      end

      # Read user attributes by name
      def read_user(username)
        output = dscl_read("/Users/#{username}")
        return nil unless output

        parse_user_output(output, username)
      rescue Errno::ENOENT
        nil
      end

      # Read group attributes by name
      def read_group(groupname)
        output = dscl_read("/Groups/#{groupname}")
        return nil unless output

        parse_group_output(output, groupname)
      rescue Errno::ENOENT
        nil
      end

      # Find user by UID (requires iteration)
      def find_user_by_uid(uid)
        each_user do |attrs|
          return attrs if attrs[:uid] == uid
        end
        nil
      end

      # Find group by GID (requires iteration)
      def find_group_by_gid(gid)
        each_group do |attrs|
          return attrs if attrs[:gid] == gid
        end
        nil
      end

      # Parse dscl user output into attributes hash
      def parse_user_output(output, username)
        attrs = parse_dscl_output(output)

        {
          name: username,
          passwd: "x", # macOS doesn't expose passwords
          uid: attrs["UniqueID"]&.first&.to_i,
          gid: attrs["PrimaryGroupID"]&.first&.to_i,
          gecos: attrs["RealName"]&.first || "",
          dir: first_value(attrs, "NFSHomeDirectory") || "/var/empty",
          shell: first_value(attrs, "UserShell") || "/usr/bin/false",
          # macOS-specific fields
          pw_change: 0,
          pw_expire: 0,
          pw_class: ""
        }
      end

      # Parse dscl group output into attributes hash
      def parse_group_output(output, groupname)
        attrs = parse_dscl_output(output)

        # GroupMembership is space-separated on a single line
        members_str = attrs["GroupMembership"]&.first || ""
        members = members_str.split

        {
          name: groupname,
          passwd: "*",
          gid: attrs["PrimaryGroupID"]&.first&.to_i,
          members: members
        }
      end

      # Parse dscl key-value output into hash
      #
      # dscl output format:
      #   Key: value1 value2 (space-separated values on same line)
      #   Key:
      #    value1 (continuation lines with leading space)
      #    value2
      #
      def parse_dscl_output(output)
        result = {}
        current_key = nil

        output.each_line do |line|
          line = line.chomp
          if line.start_with?(" ")
            # Continuation line - value is indented
            result[current_key] << line.strip if current_key && !line.strip.empty?
          elsif line.include?(":")
            key, value = line.split(":", 2)
            current_key = key.strip
            result[current_key] = []
            # Handle space-separated values on the same line
            if value && !value.strip.empty?
              # For most fields, just take the value as-is
              # Some fields like GroupMembership are space-separated member lists
              result[current_key] << value.strip
            end
          end
        end

        result
      end

      # Extract the first value from a field (handles space-separated values)
      def first_value(attrs, key)
        value = attrs[key]&.first
        return nil unless value

        # Split by space and take first token for fields that may have multiple values
        value.split.first
      end

      # Execute dscl list command
      def dscl_list(path)
        output, status = run_dscl("-list", path)
        status.success? ? output : nil
      end

      # Execute dscl read command
      def dscl_read(path)
        output, status = run_dscl("-read", path)
        status.success? ? output : nil
      end

      # Run dscl command with arguments
      def run_dscl(*args)
        require "open3"
        Open3.capture2(DSCL_PATH, LOCAL_NODE, *args)
      end
    end

    # Register the Darwin backend
    Registry.register(:darwin, Darwin.new)
  end
end
