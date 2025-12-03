# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

EtcUtils is a Ruby C extension that provides read and write access to the Linux user database files (/etc/passwd, /etc/shadow, /etc/group, /etc/gshadow). This gem wraps native C functions to safely manipulate Unix/Linux user and group databases.

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

### Travis CI
The project uses Travis CI for testing across Ruby versions 1.9.3, 2.0, 2.1, 2.2, 2.3, and ruby-head. Tests run both as normal user and with sudo.

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

### Ruby Layer

- **lib/etcutils.rb**: Loads the compiled extension and defines `EU` as shorthand for `EtcUtils`
- **lib/etcutils/version.rb**: Version constant

### Platform Differences

- **Linux**: Full support for passwd, shadow, group, gshadow with locking
- **OS X/BSD**: Read-only support recommended; limited shadow support; additional passwd fields (last_pw_change, expire, access_class)
- **nsswitch.conf**: On Ubuntu 12.04, gshadow requires manual configuration due to Debian bug #699089

### Core Classes

Each class wraps a corresponding system database:

- **EtcUtils::Passwd** → /etc/passwd
- **EtcUtils::Shadow** → /etc/shadow (requires read permissions)
- **EtcUtils::Group** → /etc/group
- **EtcUtils::GShadow** → /etc/gshadow (requires read permissions)

All classes support:
- `get/getXXent`: Iterate through entries
- `find(name_or_id)`: Find specific entry
- `parse(entry_string)`: Parse entry string, create new object
- `new(*args)`: Create new instance
- `set/setXXent`: Rewind database
- `end/endXXent`: Close database
- `fputs(io)`: Write to file handle

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

### Deprecated Methods

- `#to_s` was removed in 0.1.5 for i386 and will be removed in 1.0.0
- Use `#to_entry` instead for printing UserDB-style strings

## Testing Strategy

Tests are organized by privilege level:

- `tests/test_*.rb`: User-level tests (passwd, group reading, locking, next_uid/gid)
- `tests/root/*.rb`: Root-level tests (shadow, gshadow, writing operations)
- `tests/etcutils_test_helper.rb`: Shared test utilities

See `tests/README` for detailed test coverage mapping.
