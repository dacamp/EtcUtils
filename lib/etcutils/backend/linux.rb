# frozen_string_literal: true

module EtcUtils
  module Backend
    # Linux backend implementation
    #
    # This backend provides full read/write access to Linux user and group
    # databases using standard POSIX system calls. It reads from:
    #   - /etc/passwd for user accounts
    #   - /etc/shadow for shadow password data (requires root)
    #   - /etc/group for group definitions
    #   - /etc/gshadow for group shadow data (requires root)
    #
    # Write operations use atomic file replacement with backup support
    # and file locking via lckpwdf(3).
    #
    class Linux < Base
      PASSWD_FILE = "/etc/passwd"
      SHADOW_FILE = "/etc/shadow"
      GROUP_FILE = "/etc/group"
      GSHADOW_FILE = "/etc/gshadow"
      LOCK_FILE = "/etc/.pwd.lock"
      LOCK_TIMEOUT = 15

      def initialize
        @locked = false
        @lock_file = nil
      end

      # Iterate all users from /etc/passwd
      #
      # @yield [Hash] user attributes hash
      # @return [Enumerator] if no block given
      def each_user
        return to_enum(:each_user) unless block_given?

        File.foreach(PASSWD_FILE) do |line|
          next if line.strip.empty? || line.start_with?("#")

          attrs = parse_passwd_line(line)
          yield attrs if attrs
        end
      end

      # Iterate all groups from /etc/group
      #
      # @yield [Hash] group attributes hash
      # @return [Enumerator] if no block given
      def each_group
        return to_enum(:each_group) unless block_given?

        File.foreach(GROUP_FILE) do |line|
          next if line.strip.empty? || line.start_with?("#")

          attrs = parse_group_line(line)
          yield attrs if attrs
        end
      end

      # Find user by name or UID
      #
      # @param identifier [String, Integer] username or UID
      # @return [Hash, nil] user attributes or nil if not found
      def find_user(identifier)
        each_user do |attrs|
          if identifier.is_a?(Integer)
            return attrs if attrs[:uid] == identifier
          else
            return attrs if attrs[:name] == identifier.to_s
          end
        end
        nil
      end

      # Find group by name or GID
      #
      # @param identifier [String, Integer] group name or GID
      # @return [Hash, nil] group attributes or nil if not found
      def find_group(identifier)
        each_group do |attrs|
          if identifier.is_a?(Integer)
            return attrs if attrs[:gid] == identifier
          else
            return attrs if attrs[:name] == identifier.to_s
          end
        end
        nil
      end

      # Iterate all shadow entries from /etc/shadow
      #
      # @yield [Hash] shadow attributes hash
      # @return [Enumerator] if no block given
      # @raise [PermissionError] if insufficient permissions
      def each_shadow
        return to_enum(:each_shadow) unless block_given?

        check_shadow_permission

        File.foreach(SHADOW_FILE) do |line|
          next if line.strip.empty? || line.start_with?("#")

          attrs = parse_shadow_line(line)
          yield attrs if attrs
        end
      end

      # Iterate all gshadow entries from /etc/gshadow
      #
      # @yield [Hash] gshadow attributes hash
      # @return [Enumerator] if no block given
      # @raise [PermissionError] if insufficient permissions
      def each_gshadow
        return to_enum(:each_gshadow) unless block_given?

        check_gshadow_permission

        File.foreach(GSHADOW_FILE) do |line|
          next if line.strip.empty? || line.start_with?("#")

          attrs = parse_gshadow_line(line)
          yield attrs if attrs
        end
      end

      # Find shadow entry by username
      #
      # @param name [String] username
      # @return [Hash, nil] shadow attributes or nil
      # @raise [PermissionError] if insufficient permissions
      def find_shadow(name)
        each_shadow do |attrs|
          return attrs if attrs[:name] == name.to_s
        end
        nil
      end

      # Find gshadow entry by group name
      #
      # @param name [String] group name
      # @return [Hash, nil] gshadow attributes or nil
      # @raise [PermissionError] if insufficient permissions
      def find_gshadow(name)
        each_gshadow do |attrs|
          return attrs if attrs[:name] == name.to_s
        end
        nil
      end

      # Write passwd entries atomically
      #
      # @param entries [Array<User, Hash>] user entries to write
      # @param backup [Boolean] create backup file first
      # @param dry_run [Boolean] validate only, don't write
      # @return [DryRunResult, nil] result if dry_run, nil otherwise
      # @raise [PermissionError] if insufficient permissions
      # @raise [LockError] if lock acquisition fails
      def write_passwd(entries, backup: true, dry_run: false)
        check_write_permission(PASSWD_FILE)

        content = entries.map { |e| entry_to_passwd_line(e) }.join("\n") + "\n"
        changes = calculate_changes(PASSWD_FILE, entries, :passwd)

        if dry_run
          return DryRunResult.new(
            content: content,
            path: PASSWD_FILE,
            changes: changes,
            metadata: { entry_count: entries.length }
          )
        end

        with_lock do
          create_backup(PASSWD_FILE) if backup
          atomic_write(PASSWD_FILE, content, mode: 0o644)
        end

        nil
      end

      # Write group entries atomically
      #
      # @param entries [Array<Group, Hash>] group entries to write
      # @param backup [Boolean] create backup file first
      # @param dry_run [Boolean] validate only, don't write
      # @return [DryRunResult, nil] result if dry_run, nil otherwise
      def write_group(entries, backup: true, dry_run: false)
        check_write_permission(GROUP_FILE)

        content = entries.map { |e| entry_to_group_line(e) }.join("\n") + "\n"
        changes = calculate_changes(GROUP_FILE, entries, :group)

        if dry_run
          return DryRunResult.new(
            content: content,
            path: GROUP_FILE,
            changes: changes,
            metadata: { entry_count: entries.length }
          )
        end

        with_lock do
          create_backup(GROUP_FILE) if backup
          atomic_write(GROUP_FILE, content, mode: 0o644)
        end

        nil
      end

      # Write shadow entries atomically
      #
      # @param entries [Array<Shadow, Hash>] shadow entries to write
      # @param backup [Boolean] create backup file first
      # @param dry_run [Boolean] validate only, don't write
      # @return [DryRunResult, nil] result if dry_run, nil otherwise
      def write_shadow(entries, backup: true, dry_run: false)
        check_write_permission(SHADOW_FILE)

        content = entries.map { |e| entry_to_shadow_line(e) }.join("\n") + "\n"
        changes = calculate_changes(SHADOW_FILE, entries, :shadow)

        if dry_run
          return DryRunResult.new(
            content: content,
            path: SHADOW_FILE,
            changes: changes,
            metadata: { entry_count: entries.length }
          )
        end

        with_lock do
          create_backup(SHADOW_FILE) if backup
          atomic_write(SHADOW_FILE, content, mode: 0o640)
        end

        nil
      end

      # Write gshadow entries atomically
      #
      # @param entries [Array<GShadow, Hash>] gshadow entries to write
      # @param backup [Boolean] create backup file first
      # @param dry_run [Boolean] validate only, don't write
      # @return [DryRunResult, nil] result if dry_run, nil otherwise
      def write_gshadow(entries, backup: true, dry_run: false)
        check_write_permission(GSHADOW_FILE)

        content = entries.map { |e| entry_to_gshadow_line(e) }.join("\n") + "\n"
        changes = calculate_changes(GSHADOW_FILE, entries, :gshadow)

        if dry_run
          return DryRunResult.new(
            content: content,
            path: GSHADOW_FILE,
            changes: changes,
            metadata: { entry_count: entries.length }
          )
        end

        with_lock do
          create_backup(GSHADOW_FILE) if backup
          atomic_write(GSHADOW_FILE, content, mode: 0o640)
        end

        nil
      end

      # Execute block with system-wide password file lock
      #
      # @param timeout [Integer] seconds to wait for lock
      # @yield executes block with lock held
      # @return block result
      # @raise [LockError] if lock cannot be acquired
      def with_lock(timeout: LOCK_TIMEOUT)
        acquire_lock(timeout)
        begin
          yield
        ensure
          release_lock
        end
      end

      # Check if currently holding the lock
      #
      # @return [Boolean] true if locked
      def locked?
        @locked
      end

      # Return platform identifier
      #
      # @return [Symbol] :linux
      def platform_name
        :linux
      end

      # Return platform capability hash
      #
      # @return [Hash] nested capability structure
      def capabilities
        {
          os: :linux,
          os_version: Platform.os_version,
          etcutils_version: VERSION,
          users: { read: true, write: true },
          groups: { read: true, write: true },
          shadow: { read: true, write: true },
          gshadow: { read: true, write: true },
          locking: true
        }
      end

      private

      # Parse /etc/passwd line into attributes hash
      def parse_passwd_line(line)
        parts = line.chomp.split(":", -1)
        return nil if parts.length < 7

        {
          name: parts[0],
          passwd: parts[1],
          uid: parts[2].to_i,
          gid: parts[3].to_i,
          gecos: parts[4],
          dir: parts[5],
          shell: parts[6]
        }
      end

      # Parse /etc/group line into attributes hash
      def parse_group_line(line)
        parts = line.chomp.split(":", -1)
        return nil if parts.length < 4

        members_str = parts[3] || ""
        {
          name: parts[0],
          passwd: parts[1],
          gid: parts[2].to_i,
          members: members_str.empty? ? [] : members_str.split(",")
        }
      end

      # Parse /etc/shadow line into attributes hash
      def parse_shadow_line(line)
        parts = line.chomp.split(":", -1)
        return nil if parts.length < 9

        {
          name: parts[0],
          passwd: parts[1],
          last_change: parse_int(parts[2]),
          min_days: parse_int(parts[3]),
          max_days: parse_int(parts[4]),
          warn_days: parse_int(parts[5]),
          inactive_days: parse_int(parts[6]),
          expire_date: parse_int(parts[7]),
          reserved: parts[8].empty? ? nil : parts[8]
        }
      end

      # Parse /etc/gshadow line into attributes hash
      def parse_gshadow_line(line)
        parts = line.chomp.split(":", -1)
        return nil if parts.length < 4

        admins_str = parts[2] || ""
        members_str = parts[3] || ""

        {
          name: parts[0],
          passwd: parts[1],
          admins: admins_str.empty? ? [] : admins_str.split(","),
          members: members_str.empty? ? [] : members_str.split(",")
        }
      end

      def parse_int(str)
        return nil if str.nil? || str.empty?
        Integer(str)
      rescue ArgumentError
        nil
      end

      # Convert entry to passwd line
      def entry_to_passwd_line(entry)
        entry = entry.to_h if entry.respond_to?(:to_h) && !entry.is_a?(Hash)
        "#{entry[:name]}:#{entry[:passwd]}:#{entry[:uid]}:#{entry[:gid]}:" \
          "#{entry[:gecos]}:#{entry[:dir]}:#{entry[:shell]}"
      end

      # Convert entry to group line
      def entry_to_group_line(entry)
        entry = entry.to_h if entry.respond_to?(:to_h) && !entry.is_a?(Hash)
        members = (entry[:members] || []).join(",")
        "#{entry[:name]}:#{entry[:passwd]}:#{entry[:gid]}:#{members}"
      end

      # Convert entry to shadow line
      def entry_to_shadow_line(entry)
        entry = entry.to_h if entry.respond_to?(:to_h) && !entry.is_a?(Hash)
        [
          entry[:name],
          entry[:passwd],
          format_int(entry[:last_change]),
          format_int(entry[:min_days]),
          format_int(entry[:max_days]),
          format_int(entry[:warn_days]),
          format_int(entry[:inactive_days]),
          format_int(entry[:expire_date]),
          entry[:reserved] || ""
        ].join(":")
      end

      # Convert entry to gshadow line
      def entry_to_gshadow_line(entry)
        entry = entry.to_h if entry.respond_to?(:to_h) && !entry.is_a?(Hash)
        admins = (entry[:admins] || []).join(",")
        members = (entry[:members] || []).join(",")
        "#{entry[:name]}:#{entry[:passwd]}:#{admins}:#{members}"
      end

      def format_int(val)
        val.nil? ? "" : val.to_s
      end

      # Check shadow file read permission
      def check_shadow_permission
        unless File.readable?(SHADOW_FILE)
          raise PermissionError.new(
            "Cannot read #{SHADOW_FILE}",
            path: SHADOW_FILE,
            operation: :read,
            required_privilege: :root
          )
        end
      end

      # Check gshadow file read permission
      def check_gshadow_permission
        unless File.readable?(GSHADOW_FILE)
          raise PermissionError.new(
            "Cannot read #{GSHADOW_FILE}",
            path: GSHADOW_FILE,
            operation: :read,
            required_privilege: :root
          )
        end
      end

      # Check write permission for a file
      def check_write_permission(path)
        dir = File.dirname(path)
        unless File.writable?(dir)
          raise PermissionError.new(
            "Cannot write to #{path}",
            path: path,
            operation: :write,
            required_privilege: :root
          )
        end
      end

      # Create backup of file
      def create_backup(path)
        backup_path = "#{path}-"
        FileUtils.cp(path, backup_path, preserve: true) if File.exist?(path)
      end

      # Atomic write using temp file and rename
      def atomic_write(path, content, mode: 0o644)
        require "tempfile"
        require "fileutils"

        dir = File.dirname(path)
        temp = Tempfile.new(File.basename(path), dir)
        begin
          temp.write(content)
          temp.close
          File.chmod(mode, temp.path)

          # Copy ownership from original file if it exists
          if File.exist?(path)
            stat = File.stat(path)
            File.chown(stat.uid, stat.gid, temp.path)
          end

          File.rename(temp.path, path)
        rescue StandardError
          temp.unlink if temp
          raise
        end
      end

      # Acquire password file lock
      def acquire_lock(timeout)
        return if @locked

        @lock_file = File.open(LOCK_FILE, File::RDWR | File::CREAT, 0o600)

        deadline = Time.now + timeout
        while Time.now < deadline
          if @lock_file.flock(File::LOCK_EX | File::LOCK_NB)
            @locked = true
            return
          end
          sleep 0.1
        end

        @lock_file.close
        @lock_file = nil
        raise LockError.new(
          "Could not acquire password file lock",
          timeout: timeout,
          path: LOCK_FILE
        )
      end

      # Release password file lock
      def release_lock
        return unless @locked

        @lock_file&.flock(File::LOCK_UN)
        @lock_file&.close
        @lock_file = nil
        @locked = false
      end

      # Calculate changes between current file and new entries
      def calculate_changes(path, new_entries, type)
        changes = []

        # Read current entries
        current = {}
        if File.exist?(path)
          File.foreach(path) do |line|
            next if line.strip.empty? || line.start_with?("#")
            parts = line.chomp.split(":", 2)
            current[parts[0]] = line.chomp if parts[0]
          end
        end

        # Build new entries map
        new_map = {}
        new_entries.each do |entry|
          entry = entry.to_h if entry.respond_to?(:to_h) && !entry.is_a?(Hash)
          name = entry[:name]
          new_line = case type
                     when :passwd then entry_to_passwd_line(entry)
                     when :group then entry_to_group_line(entry)
                     when :shadow then entry_to_shadow_line(entry)
                     when :gshadow then entry_to_gshadow_line(entry)
                     end
          new_map[name] = new_line
        end

        # Find added and modified
        new_map.each do |name, line|
          if current[name].nil?
            changes << { type: :added, name: name }
          elsif current[name] != line
            changes << { type: :modified, name: name }
          end
        end

        # Find removed
        current.each_key do |name|
          changes << { type: :removed, name: name } unless new_map[name]
        end

        changes
      end
    end

    # Register the Linux backend
    Registry.register(:linux, Linux.new) if Platform.os == :linux
  end
end
