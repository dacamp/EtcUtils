# EtcUtils

[![CI](https://github.com/dacamp/etcutils/actions/workflows/ci.yml/badge.svg)](https://github.com/dacamp/etcutils/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/etcutils.svg)](https://badge.fury.io/rb/etcutils)

Cross-platform Ruby library for reading and writing system user and group databases.

## Version 2.0

EtcUtils v2 is a cross-platform rewrite with a Ruby-idiomatic API supporting Linux, macOS, and Windows.

**Looking for v1?** The legacy C extension API is available on the [`v1-legacy`](https://github.com/dacamp/EtcUtils/tree/v1-legacy) branch. v1 remains supported for bug fixes but new features target v2.

## Installation

```bash
gem install etcutils
```

**Warning:** This gem modifies system user databases. Always backup files before writing and use the temp-file-then-move pattern (like `useradd` does).

## Platform Support

| Platform | Users | Groups | Shadow | GShadow | Locking |
|----------|-------|--------|--------|---------|---------|
| Linux    | R/W   | R/W    | R/W    | R/W     | Yes     |
| macOS    | Read  | Read   | No     | No      | No      |
| Windows  | Read  | Read   | No     | No      | No      |

**Note:** Shadow file access requires root or shadow group membership on Linux.

## Quick Start (v2 API)

```ruby
require 'etcutils'

# List users and groups
EtcUtils.users.each { |user| puts user.name }
EtcUtils.groups.each { |group| puts group.name }

# Find by name or ID
user = EtcUtils.users.get("root")      # or EtcUtils.users[0]
group = EtcUtils.groups.get("wheel")   # or EtcUtils.groups[0]

# Check platform capabilities
EtcUtils.supports?(:shadow)  # => true on Linux, false on macOS
EtcUtils.capabilities        # => { os: :linux, users: { read: true, write: true }, ... }

# Write operations (Linux only, requires root)
EtcUtils.with_lock do
  EtcUtils.write_passwd(entries, backup: true)
end
```

## Data Classes

| Class | Source | Attributes |
|-------|--------|------------|
| `EtcUtils::User` | passwd/dscl | name, passwd, uid, gid, gecos, dir, shell |
| `EtcUtils::Group` | group/dscl | name, passwd, gid, members |
| `EtcUtils::Shadow` | /etc/shadow | name, passwd, last_change, min_days, max_days, warn_days, inactive_days, expire_date |
| `EtcUtils::GShadow` | /etc/gshadow | name, passwd, admins, members |

All classes support `parse(entry_string)` and `to_entry` for round-trip serialization.

## File Locking (Linux only)

```ruby
EtcUtils.with_lock(timeout: 15) do
  # Safe operations here
  # Automatically unlocks even on exception
end

EtcUtils.locked?  # => true/false
```

## Collections API

```ruby
# UserCollection
EtcUtils.users.each { |u| ... }      # iterate all users
EtcUtils.users.get("name")           # find by name, returns nil if not found
EtcUtils.users.get(uid)              # find by UID
EtcUtils.users["name"]               # alias for get
EtcUtils.users.fetch("name")         # raises NotFoundError if not found
EtcUtils.users.exists?("name")       # check existence

# GroupCollection - same interface
EtcUtils.groups.get("wheel")
EtcUtils.groups[0]
```

## Writing Entries (Linux only)

```ruby
# Dry run - validate without writing
result = EtcUtils.write_passwd(entries, dry_run: true)
result.valid?        # => true/false
result.errors        # => ["Duplicate UID 1000", ...]
result.warnings      # => ["Shell does not exist: /bin/zsh", ...]
result.preview       # => formatted preview of changes

# Write with automatic backup
EtcUtils.with_lock do
  EtcUtils.write_passwd(entries, backup: true)
  EtcUtils.write_group(groups, backup: true)
  EtcUtils.write_shadow(shadows, backup: true)   # requires root
  EtcUtils.write_gshadow(gshadows, backup: true) # requires root
end
```

## Error Handling

```ruby
begin
  EtcUtils.users.fetch("nonexistent")
rescue EtcUtils::NotFoundError => e
  puts "User not found"
end

# Available exceptions:
# - EtcUtils::Error (base class)
# - EtcUtils::NotFoundError
# - EtcUtils::PermissionError
# - EtcUtils::ValidationError
# - EtcUtils::LockError
# - EtcUtils::UnsupportedError
```

---

## v1 Legacy API

The v1 C extension API remains available for backward compatibility when the extension is compiled:

```ruby
# v1 class names (still work in v2)
EtcUtils::Passwd.find('daemon')
EtcUtils::Group.find('wheel')

# v1 iteration
EtcUtils::Passwd.each { |u| puts u.name }

# v1 locking
EtcUtils.lock { ... }
EtcUtils.locked?
```

For full v1 documentation, see the [`v1-legacy`](https://github.com/dacamp/EtcUtils/tree/v1-legacy) branch.
