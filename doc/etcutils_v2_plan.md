# EtcUtils v2 Design and Implementation Plan

> **Status:** Final
> **Version:** 2.0.0
> **Last Updated:** 2025-12-04

---

## 1. Goals and Non-Goals

### Goals

1. **Cross-platform user/group inspection** - Provide a unified read API across Linux, macOS, and Windows
2. **Safe write operations on Linux** - Enable user/group creation and modification on Linux with explicit safety mechanisms
3. **Read-only support on macOS and Windows** - Consistent read API; write operations intentionally deferred
4. **Ruby-idiomatic API** - Feel natural to Ruby developers with clear, discoverable methods
5. **Explicit capability discovery** - Allow runtime queries of what operations are supported on the current platform
6. **Fail-safe by default** - Dangerous operations require explicit opt-in; automatic backups; clear privilege requirements
7. **Dry-run support** - Preview changes before writing to disk

### Non-Goals

1. **Password hashing or encryption** - Use dedicated libraries (bcrypt, argon2). EtcUtils accepts only pre-hashed passwords.
2. **LDAP/Active Directory integration** - Out of scope. Use `net-ldap` for directory services.
3. **Windows write operations** - Fundamentally different security model (SAM database). Windows is read-only.
4. **macOS write operations in v2.0.0** - Deferred to future release; see Future Work section.
5. **Full identity lifecycle management** - No home directory creation, quota setup, SSH key management, or PAM configuration.
6. **NSS/SSSD backend queries** - Focus on local databases only; merged views from multiple sources are out of scope.

---

## 2. Current State Summary

### What EtcUtils v1 Does

EtcUtils v1 is a Ruby C extension providing read/write access to Unix user database files:

| File | Linux | macOS | Purpose |
|------|-------|-------|---------|
| `/etc/passwd` | Full R/W | Read-only | User accounts |
| `/etc/shadow` | Full R/W (root) | N/A | Password hashes and aging |
| `/etc/group` | Full R/W | Read-only | Group definitions |
| `/etc/gshadow` | Full R/W (root) | N/A | Group passwords and admins |

**System calls wrapped:**
- `getpwent`, `getpwnam`, `getpwuid`, `setpwent`, `endpwent`, `fgetpwent`, `putpwent`, `sgetpwent`
- `getspent`, `getspnam`, `setspent`, `endspent`, `fgetspent`, `putspent`, `sgetspent`
- `getgrent`, `getgrnam`, `getgrgid`, `setgrent`, `endgrent`, `fgetgrent`, `putgrent`, `sgetgrent`
- `getsgent`, `getsgnam`, `setsgent`, `endsgent`, `fgetsgent`, `putsgent`, `sgetsgent`
- `lckpwdf`, `ulckpwdf` (file locking)

### Current Limitations

1. **No Windows support** - POSIX-only headers (`pwd.h`, `grp.h`, `shadow.h`, `gshadow.h`)
2. **macOS limitations** - No shadow/gshadow; no file locking; extended passwd fields handled but writes discouraged
3. **Mixed API patterns** - Some methods on `EtcUtils` module, others on classes (`EtcUtils::Passwd`, etc.)
4. **C-like API** - `fputs`, `to_entry` feel procedural rather than Ruby-idiomatic
5. **Implicit privilege requirements** - Not always clear what requires root

---

## 3. Proposed Ruby API

### Design Principles

1. **Fail explicitly, never silently** - Raise exceptions with actionable messages
2. **Capability-first programming** - Check `Platform.supports?` before attempting operations
3. **Explicit persistence** - No auto-save; all writes require explicit method calls
4. **Automatic backup by default** - Write operations create backups unless explicitly disabled

### Core Classes and Modules

```ruby
module EtcUtils
  VERSION = "2.0.0"

  # Top-level accessors (read operations)
  def self.users   # => UserCollection (Enumerable)
  def self.groups  # => GroupCollection (Enumerable)

  # Platform introspection
  module Platform
    def self.os                    # => :linux, :darwin, :windows
    def self.supports?(feature)    # => true/false
    def self.capabilities          # => Hash (nested structure, see below)
  end

  # Write operations (explicit namespace)
  module Write
    def self.passwd(backup: true, dry_run: false, &block)
    def self.group(backup: true, dry_run: false, &block)
    def self.shadow(backup: true, dry_run: false, &block)
    def self.gshadow(backup: true, dry_run: false, &block)
  end

  # File locking (Linux only)
  def self.lock(timeout: 15, &block)
  def self.locked?
end

# Shorthand alias
EU = EtcUtils
```

### Collections API

Collections include `Enumerable` and provide convenient lookup methods:

```ruby
class UserCollection
  include Enumerable

  # Lookup by identifier - returns nil if not found
  def get(identifier)
    case identifier
    when Integer then find_by_uid(identifier)
    when String  then find_by_name(identifier)
    else raise ArgumentError, "Expected String or Integer"
    end
  end
  alias [] get

  # Lookup with exception on not found (like Hash#fetch)
  def fetch(identifier, *default, &block)
    result = get(identifier)
    return result if result
    return yield(identifier) if block_given?
    return default.first unless default.empty?
    raise NotFoundError, "No user found for: #{identifier.inspect}"
  end

  # Standard Enumerable - block-based search preserved
  def each(&block)
    # yields User objects
  end
end
```

**Usage examples:**

```ruby
# By name (String)
EtcUtils.users['root']           # => User or nil
EtcUtils.users.get('root')       # => User or nil
EtcUtils.users.fetch('root')     # => User or raises NotFoundError

# By UID (Integer)
EtcUtils.users[0]                # => User (root) or nil
EtcUtils.users[1000]             # => User or nil

# With default value
EtcUtils.users.fetch('missing', nil)  # => nil
EtcUtils.users.fetch('missing') { |name| create_user(name) }

# Enumerable#find preserved for block-based search
EtcUtils.users.find { |u| u.shell == '/bin/bash' }
```

### Platform Capabilities Structure

The `Platform.capabilities` method returns a nested hash:

```ruby
# Linux example
EtcUtils::Platform.capabilities
# => {
#      os: :linux,
#      os_version: '6.1.0',
#      etcutils_version: '2.0.0',
#      users:   { read: true, write: true },
#      groups:  { read: true, write: true },
#      shadow:  { read: true, write: true },
#      gshadow: { read: true, write: true },
#      locking: true
#    }

# macOS example
# => {
#      os: :darwin,
#      os_version: '23.0.0',
#      etcutils_version: '2.0.0',
#      users:   { read: true, write: false },
#      groups:  { read: true, write: false },
#      shadow:  { read: false, write: false },
#      gshadow: { read: false, write: false },
#      locking: false
#    }

# Windows example
# => {
#      os: :windows,
#      os_version: '10.0.19041',
#      etcutils_version: '2.0.0',
#      users:   { read: true, write: false },
#      groups:  { read: true, write: false },
#      shadow:  { read: false, write: false },
#      gshadow: { read: false, write: false },
#      locking: false
#    }
```

### Dry Run Support

Write operations support a `dry_run:` keyword that validates changes without writing to disk:

```ruby
result = EtcUtils::Write.passwd(dry_run: true) do |users|
  users + [new_user]
end

result.valid?       # => true (validation passed)
result.content      # => String (file contents that would be written)
result.path         # => "/etc/passwd"
result.backup_path  # => "/etc/passwd-"
result.diff         # => String (unified diff from current file)
```

When `dry_run: true`:
- All parsing and validation runs normally
- `ValidationError` raised if input is invalid
- No files are modified on disk
- Returns a `DryRunResult` object with the proposed changes

### Value Objects

```ruby
# User entry (from /etc/passwd)
EtcUtils::User = Struct.new(
  :name, :passwd, :uid, :gid, :gecos, :dir, :shell,
  # Platform-specific fields (nil when not applicable)
  :pw_change,     # macOS: last password change time
  :pw_expire,     # macOS: account expiration
  :pw_class,      # macOS: login class
  :sid,           # Windows: Security Identifier string
  keyword_init: true
) do
  alias home dir

  # Returns hash of platform-specific fields for current OS
  def platform_fields
    case EtcUtils::Platform.os
    when :windows then { sid: sid }
    when :darwin  then { pw_change: pw_change, pw_expire: pw_expire, pw_class: pw_class }
    else {}
    end
  end
end

# Group entry (from /etc/group)
EtcUtils::Group = Struct.new(
  :name, :passwd, :gid, :members,  # members is Array<String>
  :sid,           # Windows: Security Identifier string
  keyword_init: true
) do
  def platform_fields
    case EtcUtils::Platform.os
    when :windows then { sid: sid }
    else {}
    end
  end
end

# Shadow entry (from /etc/shadow, Linux only)
EtcUtils::Shadow = Struct.new(
  :name, :passwd, :last_change, :min_days, :max_days,
  :warn_days, :inactive_days, :expire_date, :reserved,
  keyword_init: true
)

# GShadow entry (from /etc/gshadow, Linux only)
EtcUtils::GShadow = Struct.new(
  :name, :passwd, :admins, :members,  # admins/members are Array<String>
  keyword_init: true
)
```

### Exception Hierarchy

```ruby
module EtcUtils
  class Error < StandardError; end

  class NotFoundError < Error; end

  # PermissionError includes platform-specific hints
  class PermissionError < Error
    attr_reader :path, :operation, :required_privilege

    def initialize(message = nil, path: nil, operation: nil, required_privilege: nil)
      @path = path
      @operation = operation
      @required_privilege = required_privilege
      super(message || build_message)
    end

    private

    def build_message
      base = "Permission denied"
      base += " #{operation}" if operation
      base += " #{path}" if path
      "#{base}. #{platform_hint}"
    end

    def platform_hint
      case EtcUtils::Platform.os
      when :linux
        "Try running with sudo."
      when :darwin
        "Try running with sudo or use native Directory Services tools."
      when :windows
        "Write operations are not supported on Windows. See documentation for alternatives."
      else
        "Check your permissions."
      end
    end
  end

  class UnsupportedError < Error; end
  class LockError < Error
    attr_reader :timeout
    def initialize(message = nil, timeout: nil)
      @timeout = timeout
      super(message)
    end
  end
  class ValidationError < Error; end
  class ConcurrentModificationError < Error; end
end
```

### Usage Examples

#### Basic Read Operations

```ruby
require 'etcutils'

# Get a user by name (bracket syntax)
user = EtcUtils.users['root']
puts user.name      # => "root"
puts user.uid       # => 0
puts user.home      # => "/root"

# Get by UID
user = EtcUtils.users[1000]

# Fetch raises if not found
user = EtcUtils.users.fetch('root')     # => User
user = EtcUtils.users.fetch('missing')  # => raises NotFoundError

# Fetch with default
user = EtcUtils.users.fetch('missing', nil)  # => nil

# Iterate all users
EtcUtils.users.each { |u| puts u.name }

# Filter with Enumerable (find with block preserved)
humans = EtcUtils.users.select { |u| u.uid >= 1000 }
bash_user = EtcUtils.users.find { |u| u.shell == '/bin/bash' }

# Groups work the same way
group = EtcUtils.groups['wheel']
puts group.members  # => ["root"]
```

#### Create/Update Operations (Linux)

```ruby
require 'etcutils'

# Create a new user
new_user = EtcUtils::User.new(
  name: 'deploy',
  passwd: 'x',
  uid: EtcUtils.next_uid,
  gid: EtcUtils.next_gid,
  gecos: 'Deploy User',
  dir: '/home/deploy',
  shell: '/bin/bash'
)

# Preview changes with dry_run (no disk writes)
result = EtcUtils::Write.passwd(dry_run: true) do |users|
  users + [new_user]
end
puts result.diff  # Shows unified diff of proposed changes

# Write with automatic backup and locking
EtcUtils.lock do
  EtcUtils::Write.passwd(backup: true) do |users|
    users + [new_user]
  end
end

# Update an existing user
EtcUtils.lock do
  EtcUtils::Write.passwd do |users|
    users.map do |u|
      u.name == 'deploy' ? EtcUtils::User.new(**u.to_h, shell: '/bin/zsh') : u
    end
  end
end
```

#### Capability Checking

```ruby
require 'etcutils'

puts EtcUtils::Platform.os  # => :linux, :darwin, or :windows

# Check specific features
if EtcUtils::Platform.supports?(:shadow)
  EtcUtils.shadows.each { |s| puts s.name }
end

if EtcUtils::Platform.supports?(:users_write)
  # Proceed with modifications
else
  puts "Write operations not supported on this platform"
end

# Get full capabilities (nested structure)
caps = EtcUtils::Platform.capabilities
# => {
#      os: :linux,
#      os_version: '6.1.0',
#      etcutils_version: '2.0.0',
#      users:   { read: true, write: true },
#      groups:  { read: true, write: true },
#      shadow:  { read: true, write: true },
#      gshadow: { read: true, write: true },
#      locking: true
#    }

# Check nested capabilities
if caps[:users][:write]
  # Can write users on this platform
end
```

#### Error Handling

```ruby
require 'etcutils'

begin
  EtcUtils::Write.passwd do |users|
    users + [new_user]
  end
rescue EtcUtils::PermissionError => e
  abort "Error: Need root privileges. Try: sudo #{$0}"
rescue EtcUtils::UnsupportedError => e
  abort "Error: #{e.message}"
rescue EtcUtils::LockError => e
  abort "Error: Could not acquire lock (timeout: #{e.timeout}s)"
rescue EtcUtils::ConcurrentModificationError => e
  abort "Error: File was modified by another process"
end
```

---

## 4. Architecture and Platform-Specific Design

### File Structure

```
lib/
├── etcutils.rb                    # Main entry point
├── etcutils/
│   ├── version.rb                 # VERSION constant
│   ├── errors.rb                  # Exception classes
│   ├── platform.rb                # Platform detection
│   ├── user.rb                    # User struct
│   ├── group.rb                   # Group struct
│   ├── shadow.rb                  # Shadow struct
│   ├── users.rb                   # UserCollection
│   ├── groups.rb                  # GroupCollection
│   ├── write.rb                   # Write operations
│   └── backend/
│       ├── base.rb                # Abstract backend interface
│       ├── registry.rb            # Backend selection
│       ├── linux.rb               # Linux backend (loads C extension)
│       ├── darwin.rb              # macOS backend (FFI)
│       └── windows.rb             # Windows backend (FFI)
│
ext/
└── etcutils_linux/
    ├── extconf.rb                 # mkmf configuration
    ├── etcutils_linux.c           # Main extension
    ├── etcutils_linux.h           # Headers
    ├── passwd.c                   # Passwd/Shadow functions
    └── group.c                    # Group/GShadow functions
```

### Backend Interface

Each platform backend implements this interface:

```ruby
module EtcUtils::Backend
  class Base
    # Required - iterate users/groups
    def each_user;  raise NotImplementedError; end
    def each_group; raise NotImplementedError; end
    def find_user(identifier);  raise NotImplementedError; end
    def find_group(identifier); raise NotImplementedError; end

    # Optional - shadow/gshadow (default: raise UnsupportedError)
    def each_shadow;  raise UnsupportedError; end
    def each_gshadow; raise UnsupportedError; end
    def find_shadow(name);  raise UnsupportedError; end
    def find_gshadow(name); raise UnsupportedError; end

    # Optional - write operations (default: raise UnsupportedError)
    def write_passwd(entries, backup: true);  raise UnsupportedError; end
    def write_group(entries, backup: true);   raise UnsupportedError; end
    def write_shadow(entries, backup: true);  raise UnsupportedError; end
    def write_gshadow(entries, backup: true); raise UnsupportedError; end

    # Optional - file locking (default: raise UnsupportedError)
    def with_lock(&block); raise UnsupportedError; end

    # Required - capability queries
    def platform_name; raise NotImplementedError; end
    def capabilities;  raise NotImplementedError; end
    def supports?(feature); capabilities.fetch(feature, false); end
  end
end
```

### Platform-Specific Details

#### Linux (C Extension)

**Implementation:** C extension wrapping POSIX and glibc functions

**APIs used:**
- `getpwent`, `getpwnam`, `getpwuid`, `setpwent`, `endpwent`
- `getspent`, `getspnam`, `setspent`, `endspent` (shadow.h)
- `getgrent`, `getgrnam`, `getgrgid`, `setgrent`, `endgrent`
- `getsgent`, `getsgnam`, `setsgent`, `endsgent` (gshadow.h)
- `lckpwdf`, `ulckpwdf` (file locking)
- `fgetpwent`, `fgetgrent`, `fgetspent`, `fgetsgent` (file I/O)
- `putpwent`, `putgrent`, `putspent`, `putsgent` (file I/O)

**Capabilities:**
```ruby
{
  read_passwd: true,  write_passwd: true,
  read_shadow: true,  write_shadow: true,   # Requires root
  read_group: true,   write_group: true,
  read_gshadow: true, write_gshadow: true,  # Requires root
  locking: true
}
```

**Required permissions:**
- Read passwd/group: none (world-readable)
- Read shadow/gshadow: root or shadow group membership
- Write any file: root

**Why C extension over FFI:**
1. `lckpwdf` requires proper cleanup even on exceptions
2. Shadow/gshadow iteration benefits from native memory management
3. Existing battle-tested code from v1
4. Performance for large user databases (LDAP-backed systems)

#### macOS (FFI) - Read-Only in v2.0.0

**Implementation:** FFI to libc functions (read-only)

**APIs used:**
- `getpwent`, `getpwnam`, `getpwuid`, `setpwent`, `endpwent`
- `getgrent`, `getgrnam`, `getgrgid`, `setgrent`, `endgrent`

**Capabilities:**
```ruby
{
  os: :darwin,
  os_version: '23.0.0',
  etcutils_version: '2.0.0',
  users:   { read: true, write: false },
  groups:  { read: true, write: false },
  shadow:  { read: false, write: false },
  gshadow: { read: false, write: false },
  locking: false
}
```

**macOS-specific fields on User:**
- `pw_change` - last password change time (nil on other platforms)
- `pw_expire` - account expiration (nil on other platforms)
- `pw_class` - login class (nil on other platforms)

**Why read-only in v2.0.0:**
- macOS user management via `dscl` is fundamentally different from Linux file manipulation
- `dscl` involves process spawning, output parsing, and different error semantics
- No atomic operation guarantees with Directory Services
- Write support deferred to post-2.0 release (see Future Work section)

**Why FFI over C extension:**
- Simple, stable APIs
- No special locking mechanism needed
- Avoids maintaining separate macOS C extension

#### Windows (FFI) - Read-Only

**Implementation:** FFI to Win32 APIs (read-only)

**APIs used:**
- `NetUserEnum` - enumerate local users
- `NetUserGetInfo` - get user details
- `NetLocalGroupEnum` - enumerate local groups
- `NetLocalGroupGetMembers` - get group membership
- `NetApiBufferFree` - free API-allocated memory

**Capabilities:**
```ruby
{
  os: :windows,
  os_version: '10.0.19041',
  etcutils_version: '2.0.0',
  users:   { read: true, write: false },
  groups:  { read: true, write: false },
  shadow:  { read: false, write: false },
  gshadow: { read: false, write: false },
  locking: false
}
```

**Windows-specific fields:**
- `sid` - Security Identifier string (e.g., "S-1-5-21-..."). Available on both User and Group objects. Returns `nil` on other platforms.

```ruby
# Example Windows user access
user = EtcUtils.users['Administrator']
user.sid        # => "S-1-5-21-1234567890-1234567890-1234567890-500"
user.uid        # => 500 (RID portion of SID)

# Platform fields helper
user.platform_fields  # => { sid: "S-1-5-21-..." }
```

**Why read-only:**
- Windows user management requires completely different APIs (NetUserAdd, NetUserSetInfo)
- Different privilege elevation model (UAC)
- Fundamentally different data model (SAM database, not flat files)
- Better served by dedicated Windows gems or PowerShell

**Why FFI over C extension:**
- Avoids Windows C compilation toolchain complexity
- Win32 APIs are well-suited to FFI
- Read-only simplifies implementation significantly

---

## 5. Security and Permission Considerations

### Critical Safety Mechanisms

1. **Automatic backups** - Write operations create `/etc/passwd-` style backups by default
2. **File locking** - `lckpwdf`/`ulckpwdf` used on Linux to prevent concurrent modifications
3. **Atomic writes** - Write to temp file, then rename (atomic on same filesystem)
4. **Privilege checking** - Verify write permissions before attempting operations
5. **Pre-hashed passwords only** - Never accept plaintext passwords

### Race Condition Mitigations

1. **TOCTOU protection** - Verify file unchanged between read and write
2. **Stat comparison** - Check mtime, size, inode before rename
3. **Journal-based recovery** - Track operation state for crash recovery
4. **Exclusive temp files** - Use `O_EXCL` flag when creating temp files

### Input Validation

```ruby
module EtcUtils::Validation
  USERNAME_PATTERN = /\A[a-z_][a-z0-9_-]*\$?\z/i
  MAX_USERNAME_LENGTH = 32
  MAX_GECOS_LENGTH = 256

  def self.validate_username!(name)
    raise ValidationError if name.empty?
    raise ValidationError if name.length > MAX_USERNAME_LENGTH
    raise ValidationError unless name.match?(USERNAME_PATTERN)
  end

  def self.validate_hash!(hash)
    return if hash.nil? || hash == '*' || hash == '!' || hash == '!!'
    # Validate crypt(3) format
    unless hash.match?(/\A\$[0-9a-z]+\$/)
      raise ValidationError, "Invalid password hash format"
    end
  end
end
```

### Privilege Requirements Summary

| Operation | Linux | macOS | Windows |
|-----------|-------|-------|---------|
| Read passwd/group | User | User | User |
| Read shadow/gshadow | Root | N/A | N/A |
| Write passwd/group | Root | N/A (v2.0.0) | N/A |
| Write shadow/gshadow | Root | N/A | N/A |
| File locking | Root | N/A | N/A |

**Note:** macOS and Windows are read-only in v2.0.0. See Future Work for planned enhancements.

---

## 6. Testing Strategy

### Test Levels

| Level | Purpose | Privileges | CI Job |
|-------|---------|------------|--------|
| Unit | Pure Ruby logic, parsing | None | All platforms |
| Integration | Read from real system | None | All platforms |
| Privileged | Shadow, writes | Root | Linux only |
| Platform | OS-specific behavior | Varies | Per-platform |

### Directory Structure

```
test/
├── test_helper.rb                 # Common setup
├── unit/
│   ├── test_entry_parsing.rb      # String parsing
│   ├── test_entry_serialization.rb
│   ├── test_validation.rb
│   └── test_platform_detection.rb
├── integration/
│   ├── test_passwd_read.rb
│   ├── test_group_read.rb
│   └── test_enumeration.rb
├── privileged/
│   ├── test_shadow_read.rb
│   ├── test_locking.rb
│   └── test_write_operations.rb
├── platform/
│   ├── linux/
│   │   └── test_shadow_support.rb
│   └── macos/
│       └── test_passwd_extensions.rb
└── fixtures/
    ├── passwd_samples/
    ├── shadow_samples/
    └── group_samples/
```

### Test Framework

**Minitest** (recommended) - stdlib, fast, compatible with existing test-unit tests

### Mocking Strategy

1. **Fixture-based testing** - Use string fixtures for parsing tests
2. **Mock backend** - Injectable backend for write operation tests
3. **Temp directories** - All write tests use `/tmp`, never touch real system files
4. **Platform helpers** - `skip_on_macos`, `skip_unless_privileged`, etc.

### Write Operation Safety

```ruby
# All write tests use temp directories
def with_temp_passwd_file
  Dir.mktmpdir("etcutils_test") do |dir|
    path = File.join(dir, "passwd")
    yield path
  end
end
```

---

## 7. CI Plan

### GitHub Actions Matrix

```yaml
jobs:
  linux:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        ruby: ['3.0', '3.1', '3.2', '3.3', 'head']
    steps:
      - Compile C extension
      - Run tests (unprivileged)
      - Run tests (privileged via sudo)

  macos:
    runs-on: macos-latest
    strategy:
      matrix:
        ruby: ['3.2', '3.3']
        macos: ['13', '14']
    steps:
      - Compile C extension
      - Run tests (unprivileged)

  lint:
    runs-on: ubuntu-latest
    steps:
      - Validate gemspec
      - Check for compiler warnings
```

### Windows Strategy

Windows CI is deferred because:
1. C extension cannot compile (POSIX headers missing)
2. FFI-based Windows backend not yet implemented
3. Would require separate Windows-specific CI job

When Windows support is added:
```yaml
  windows:
    runs-on: windows-latest
    strategy:
      matrix:
        ruby: ['3.2', '3.3']
    steps:
      - Run tests (read-only operations only)
```

### Privileged Tests on GitHub Actions

```yaml
- name: Run privileged tests
  run: |
    sudo -E env "PATH=$PATH" \
                "GEM_HOME=$GEM_HOME" \
                "GEM_PATH=$GEM_PATH" \
      bundle exec rake test_privileged
```

GitHub Actions Linux runners have passwordless sudo.

---

## 8. Implementation Steps

### Phase 1: Core Refactoring (Foundation)

1. [ ] Create new directory structure (`lib/etcutils/`, `ext/etcutils_linux/`)
2. [ ] Define exception hierarchy (`lib/etcutils/errors.rb`)
3. [ ] Implement value object structs (User, Group, Shadow, GShadow)
4. [ ] Define backend interface (`lib/etcutils/backend/base.rb`)
5. [ ] Implement backend registry with platform detection
6. [ ] Port existing C extension to new structure
7. [ ] Add comprehensive unit tests for parsing/serialization

### Phase 2: Linux Backend (Existing Functionality)

1. [ ] Wrap Linux C extension in new backend interface
2. [ ] Implement `UserCollection` and `GroupCollection`
3. [ ] Implement `EtcUtils::Write` module with block-based API
4. [ ] Add file locking integration
5. [ ] Implement atomic write with backup
6. [ ] Add race condition detection (stat comparison)
7. [ ] Add privileged tests for shadow/gshadow

### Phase 3: macOS Backend (Read Operations)

1. [ ] Implement FFI bindings for passwd/group
2. [ ] Handle macOS-specific struct members (pw_change, pw_expire, pw_class)
3. [ ] Add platform capability detection
4. [ ] Add macOS-specific tests
5. [ ] Document macOS limitations

### Phase 4: Windows Backend (Read Operations)

1. [ ] Research Win32 API integration (NetUserEnum, etc.)
2. [ ] Implement FFI bindings
3. [ ] Handle Windows-specific user model (SID, RID)
4. [ ] Add Windows CI workflow
5. [ ] Document Windows limitations

### Phase 5: Documentation and Release

1. [ ] Write comprehensive README with examples
2. [ ] Document all public API methods
3. [ ] Create migration guide from v1 to v2
4. [ ] Security considerations document
5. [ ] Update CHANGELOG
6. [ ] Tag v2.0.0 release

---

## Appendix A: Migration from v1 to v2

| v1 API | v2 API |
|--------|--------|
| `EtcUtils::Passwd.find(x)` | `EtcUtils.users[x]` or `EtcUtils.users.get(x)` |
| `EtcUtils::Passwd.find(x)` (raise on missing) | `EtcUtils.users.fetch(x)` |
| `EtcUtils::Passwd.get { }` | `EtcUtils.users.each { }` |
| `EtcUtils::Passwd.parse(s)` | `EtcUtils::User.parse(s)` |
| `passwd.to_entry` | `user.to_entry` |
| `passwd.fputs(io)` | `EtcUtils::Write.passwd { ... }` |
| `EtcUtils.lock { }` | `EtcUtils.lock { }` (unchanged) |
| `EtcUtils.next_uid` | `EtcUtils.next_uid` (unchanged) |
| `EtcUtils.has_shadow?` | `EtcUtils::Platform.supports?(:shadow)` |
| `EU::Shadow.find(x)` | `EtcUtils.shadows[x]` or `EtcUtils.shadows.get(x)` |

**Key API Changes:**
- Collections use `get`/`[]` (returns nil) and `fetch` (raises) instead of `find`
- `find` with a block still works for Enumerable-style searches
- Platform capabilities now use nested hash structure
- Write operations support `dry_run: true` for previewing changes

---

## Appendix B: Platform Capability Matrix (v2.0.0)

| Feature | Linux | macOS | Windows |
|---------|-------|-------|---------|
| Read users | Yes | Yes | Yes |
| Read groups | Yes | Yes | Yes |
| Read shadow | Yes (root) | No | No |
| Read gshadow | Yes (root) | No | No |
| Write users | Yes (root) | **No** | No |
| Write groups | Yes (root) | **No** | No |
| Write shadow | Yes (root) | No | No |
| Write gshadow | Yes (root) | No | No |
| File locking | Yes | No | No |
| Dry run support | Yes | N/A | N/A |
| Extended passwd fields | No | Yes (`pw_change`, `pw_expire`, `pw_class`) | No |
| SID field | No | No | Yes |

**Note:** macOS write support is deferred to post-2.0 release (see Future Work).

---

## Appendix C: Key Risks

1. **Race conditions in write operations** - Mitigated by file locking, stat comparison, and atomic rename
2. **Platform divergence complexity** - Mitigated by capability discovery API and clear documentation
3. **Security vulnerabilities in C extension** - Mitigated by input validation at Ruby layer before C
4. **Maintenance burden (sole maintainer)** - Mitigated by minimal native code, comprehensive CI
5. **Breaking changes from v1** - Mitigated by migration guide and deprecation warnings

---

## Appendix D: Decision Log

| Decision | Rationale | Status |
|----------|-----------|--------|
| Use Struct over Data | Ruby 3.2+ only for Data; Struct works on 3.0+ | Locked |
| C extension for Linux, FFI for others | lckpwdf requires proper cleanup; FFI simpler elsewhere | Locked |
| Windows read-only | Fundamentally different security model; recommend dedicated tools | Locked |
| **macOS read-only in v2.0.0** | dscl-based writes are complex and risky; safer to ship read-only first | **Locked** |
| Block-based write API | Makes dangerous operations explicit; shows full file context | Locked |
| Capability-first design | Platforms differ significantly; users need runtime introspection | Locked |
| **Collections use `get`/`fetch`, not `find`** | Avoids conflict with Enumerable#find; follows Hash#fetch convention | **Locked** |
| **Capabilities use nested hashes** | Structure like `users: { read: true, write: true }` is extensible and consistent | **Locked** |
| **Write APIs support `dry_run:`** | Enables preview of changes before disk writes; returns DryRunResult object | **Locked** |
| **PermissionError includes platform hints** | Provides actionable guidance specific to each OS | **Locked** |
| **Windows SID as direct attribute** | `user.sid` is cleaner than nested hash; `platform_fields` helper for introspection | **Locked** |

---

## Appendix E: Future Work (Post-2.0)

### macOS Write Support via dscl

**Planned for:** v2.1.0 or later

macOS write operations using Directory Services (`dscl`) are intentionally deferred from v2.0.0:

```ruby
# Future API (not in v2.0.0)
EtcUtils::Write.passwd do |users|
  users + [new_user]
end  # Would use dscl commands internally
```

**Challenges to address:**
- Process spawning and output parsing for `dscl` commands
- Different error semantics vs. file-based writes
- No file locking equivalent
- Rollback complexity if partial failures occur
- Testing on multiple macOS versions

**Prerequisite:** Thorough investigation of dscl behavior across macOS versions and Directory Services configurations.

### Windows Write Support

**Planned for:** v2.2.0 or later (if at all)

Windows write operations require Win32 APIs:
- `NetUserAdd` / `NetUserSetInfo` for user management
- `NetLocalGroupAdd` / `NetLocalGroupSetInfo` for group management
- UAC privilege elevation handling

**Challenges:**
- Fundamentally different from Linux file operations
- Complex privilege model (Administrator vs. elevated)
- May be better served by dedicated Windows tools or gems

### Additional Future Enhancements

- **Audit logging** - Integrate with system audit facilities
- **SELinux context support** - Read/write SELinux user contexts
- **ACL support** - Access control list management
- **Batch operations** - Transactional multi-file updates
