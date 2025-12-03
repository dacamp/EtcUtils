# EtcUtils

[![CI](https://github.com/dacamp/etcutils/actions/workflows/ci.yml/badge.svg)](https://github.com/dacamp/etcutils/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/etcutils.svg)](https://badge.fury.io/rb/etcutils)

Ruby C extension for read/write access to Linux user databases (`/etc/passwd`, `/etc/shadow`, `/etc/group`, `/etc/gshadow`).

## Installation

```bash
gem install etcutils
```

**Warning:** This gem modifies system user databases. Always backup files before writing and use the temp-file-then-move pattern (like `useradd` does).

## Platform Support

| Platform | Read | Write |
|----------|------|-------|
| Linux    | Full | Full  |
| macOS/BSD| Full | Not recommended |

**GShadow on older Debian/Ubuntu:** If GShadow operations fail, add `gshadow: files` to `/etc/nsswitch.conf`.

## Quick Start

```ruby
require 'etcutils'

# Find users/groups by name or ID
user = EtcUtils::Passwd.find('daemon')  # or EU::Passwd.find(1)
group = EtcUtils::Group.find('daemon')

# Iterate through entries
EtcUtils::Passwd.each { |u| puts u.name }

# Create new entry (auto-assigns next available UID/GID)
new_user = EtcUtils::Passwd.parse("newuser:x:::New User:/home/newuser:/bin/bash")
```

## Classes

| Class | File | Attributes |
|-------|------|------------|
| `EtcUtils::Passwd` | `/etc/passwd` | name, passwd, uid, gid, gecos, dir, shell |
| `EtcUtils::Group` | `/etc/group` | name, passwd, gid, members |
| `EtcUtils::Shadow` | `/etc/shadow` | name, passwd, last_change, min_change, max_change, warn, inactive, expire, flag |
| `EtcUtils::GShadow` | `/etc/gshadow` | name, passwd, admins, members |

**Note:** Shadow classes require read permission on the shadow files (typically root only).

## File Locking

Use block form for automatic unlock (recommended):

```ruby
EtcUtils.lock do
  # Safe operations here
  # Automatically unlocks even on exception
end
```

Manual locking:

```ruby
EtcUtils.lock      # => true (locked)
EtcUtils.locked?   # => true
EtcUtils.unlock    # => true (unlocked)
```

## Reading Entries

```ruby
# Sequential iteration
EtcUtils::Group.get        # First entry
EtcUtils::Group.get        # Next entry
EtcUtils.setgrent          # Rewind to beginning

# Find by name or ID
EtcUtils::Passwd.find('daemon')
EtcUtils::Passwd.find(1)
```

## Creating Entries

**`parse`** - Returns existing entry if found, otherwise creates new:

```ruby
# Auto-assigns next available UID/GID when fields are blank
EtcUtils::Passwd.parse("foobar:x:::Foobar User:/home/foobar:/bin/bash")
#=> uid=1001, gid=1001 (auto-assigned)
```

**`new`** - Creates entry with explicit values:

```ruby
EtcUtils::GShadow.new("foobar", '!', nil, ['sudo', 'adm'])
```

## Writing Entries

**Always backup first, write to temp file, then move into place.**

```ruby
# 1. Backup original
File.open("#{SHADOW}-", 'w+', 0600) { |f| f.puts IO.readlines(SHADOW) }

# 2. Write to temp file with lock
EtcUtils.lock do
  File.open("/etc/_shadow", File::RDWR|File::CREAT, 0600) do |tmp|
    while (ent = EtcUtils::Shadow.get)
      ent.fputs(tmp)
    end
  end
end

# 3. Move temp file into place (not shown - use FileUtils.mv)
```

## UID/GID Management

```ruby
EtcUtils.next_uid = 1000   # Set starting point
EtcUtils.next_uid          # => 1000
EtcUtils.next_uid          # => 1001 (auto-increments to next available)
```

**Tip:** Let `parse` manage UID/GID assignment to keep them in sync for new users.
