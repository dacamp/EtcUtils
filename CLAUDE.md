# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

EtcUtils is a cross-platform Ruby library (with optional C extension for Linux) that provides read and write access to system user databases. v2 adds pure Ruby backends for macOS and Windows, while maintaining backward compatibility with the v1 C extension API.

**CRITICAL WARNING**: This gem can have catastrophic effects on a system if used incorrectly. Always create backup files (conventionally with a trailing dash, e.g., `/etc/passwd-`) before making modifications.

## Build and Test Commands

### Building the extension
```bash
bundle install
bundle exec rake compile
```

### Running tests
```bash
# Run all tests (as normal user)
bundle exec rake test

# Run tests as root (required for shadow/gshadow tests)
rvmsudo bundle exec rake test

# Run specific test file
ruby -I tests tests/test_passwd_class.rb
```

### CI
The project uses GitHub Actions for testing across Ruby versions 2.7, 3.0, 3.1, 3.2, 3.3, and ruby-head. Tests run both as normal user and with sudo.

## Architecture

### C Extension Structure

The gem is implemented as a native C extension in `ext/etcutils/`:

- **etcutils.c**: Main extension initialization and module-level functions
- **etcutils.h**: Header with platform detection, constants (PASSWD, SHADOW, GROUP, GSHADOW paths)
- **passwd.c**: Implementation of Passwd and Shadow class methods
- **group.c**: Implementation of Group and GShadow class methods
- **extconf.rb**: Build configuration that detects available system headers and functions

The build system uses `mkmf` to detect:
- Available headers (pwd.h, grp.h, shadow.h, gshadow.h)
- Available functions (lckpwdf, getpwent, sgetpwent, fgetpwent, etc.)
- Structure members (for cross-platform compatibility)

### Ruby Layer (v2)

The v2 implementation is primarily pure Ruby in `lib/etcutils/`:

- **lib/etcutils.rb**: Main entry point, loads C extension or v2 classes, defines `EU` alias
- **lib/etcutils/version.rb**: Version constant
- **lib/etcutils/errors.rb**: Exception hierarchy (Error, NotFoundError, PermissionError, etc.)
- **lib/etcutils/platform.rb**: Platform detection and capability queries
- **lib/etcutils/user.rb, group.rb, shadow.rb, gshadow.rb**: Struct-based value objects
- **lib/etcutils/users.rb, groups.rb**: Collection classes with iteration and lookup
- **lib/etcutils/dry_run_result.rb**: Validation result for write operations
- **lib/etcutils/backend/**: Platform-specific implementations
  - **base.rb**: Abstract backend interface
  - **registry.rb**: Backend selection and registration
  - **linux.rb**: Linux backend (file parsing, atomic writes, flock locking)
  - **darwin.rb**: macOS backend (dscl-based)
  - **windows.rb**: Windows backend (stub, FFI-based in future)

### Platform Differences

- **Linux**: Full read/write support for passwd, shadow, group, gshadow with file locking
- **macOS**: Read-only via dscl; no shadow/gshadow; additional passwd fields (pw_change, pw_expire, pw_class)
- **Windows**: Read-only via WinAPI (stub implementation, FFI-based in future)
- **nsswitch.conf**: On older Debian/Ubuntu, gshadow may require `gshadow: files` in nsswitch.conf

### Core Classes

**v2 API (Struct-based):**
- **EtcUtils::User** - User entry with name, passwd, uid, gid, gecos, dir, shell
- **EtcUtils::Group** - Group entry with name, passwd, gid, members
- **EtcUtils::Shadow** - Shadow entry (Linux only)
- **EtcUtils::GShadow** - GShadow entry (Linux only)

All v2 classes support:
- `parse(entry_string)`: Parse colon-delimited entry string
- `to_entry`: Serialize back to colon-delimited string
- `to_h(compact: false)`: Convert to hash
- Keyword argument initialization: `User.new(name: "test", uid: 1000)`

**v1 API (C extension, Linux only):**
- **EtcUtils::Passwd** → /etc/passwd (aliased as `User` when C extension loads)
- **EtcUtils::Shadow** → /etc/shadow
- **EtcUtils::Group** → /etc/group
- **EtcUtils::GShadow** → /etc/gshadow

v1 classes support: `get`, `find`, `parse`, `new`, `set`, `end`, `fputs`

### File Locking Mechanism

The extension wraps `lckpwdf(3)` for safe concurrent access:

- `EtcUtils.lock { block }`: Preferred method - always unlocks after block
- `EtcUtils.lckpwdf` / `unlock`: Manual locking
- `EtcUtils.locked?`: Check lock state

### UID/GID Management

- `EtcUtils.next_uid` / `next_gid`: Auto-increment counters for new users/groups
- `next_uid=` / `next_gid=`: Set starting values
- `parse` method attempts to keep uid/gid in sync for new users

## Development Guidelines

### Adding New Features

When modifying the C extension:

1. Update `extconf.rb` if adding new system function dependencies
2. Use `#ifdef` guards for platform-specific code
3. Add corresponding tests in both `tests/` (user-level) and `tests/root/` (privileged)
4. Update both module-level functions and class methods if applicable

### Safe File Writing Pattern

Never write directly to /etc files. Follow this pattern:

```ruby
# 1. Create backup
stat = File.stat(PASSWD).dup
File.open(PASSWD + '-', 'w+', 0600) { |bf| bf.puts IO.readlines(PASSWD) }

# 2. Write to temp file with locking
tmp = "/etc/_passwd"
EtcUtils.lock {
  File.open(tmp, File::RDWR|File::CREAT, 0600) { |tmp_fh|
    EtcUtils::Passwd.set
    while (ent = EtcUtils::Passwd.get)
      ent.fputs(tmp_fh)
    end
  }
}

# 3. Move temp file into place (atomic operation)
File.rename(tmp, PASSWD)
```

### Deprecated Methods (v1)

- `#to_s` was removed in 0.1.5; use `#to_entry` instead for UserDB-style strings

## Testing Strategy

Tests are organized by API version and privilege level:

**v1 tests:**
- `tests/test_*.rb`: User-level tests (passwd, group reading, locking, next_uid/gid)
- `tests/root/*.rb`: Root-level tests (shadow, gshadow, writing operations)
- `tests/etcutils_test_helper.rb`: Shared test utilities

**v2 tests:**
- `tests/v2/test_*.rb`: v2 API tests (platform, backend, collections, value objects)
- `tests/v2/test_helper.rb`: v2 test utilities with platform skip helpers

v2 tests automatically skip when the v1 C extension is loaded (detected via `V1_EXTENSION_LOADED` constant).
