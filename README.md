EtcUtils
======

Ruby C Extension for read and write access to the Linux user database.

    gem install etcutils

This gem can have catastrophic effects on your system if used incorrectly.  I eventually would like to get to the point that it does all the hard thinking for you when it comes to writing to file, but for now you'll need to write your own tmp file (like /etc/passwd-) before moving it into place.  This has worked for years for ```useradd``` and ```adduser``` and you should try keep that same mentality.


## Know Issues

Verified on Ubuntu 12.04, nsswitch.conf is misconfigured due to a known [bug](http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=699089).  You will be unable to manipulate /etc/gshadow until this line is added to /etc/nsswitch.conf.

    gshadow:        files


## Structs

##### EtcUtils::Passwd

```ruby
EtcUtils.find_pwd(1 || 'daemon')
EtcUtils::Passwd.find('daemon' || 1)
=> # <struct EtcUtils::Passwd name="daemon", passwd="x", uid=1, gid=1, gecos="daemon", dir="/usr/sbin", shell="/bin/sh">
```

* `:name`: This is the user’s login name. It should not contain capital letters.

* `:passwd`: This is either the encrypted user password, an asterisk (*), or the letter aqxaq. (See `pwconv(8)` for an explanation of aqxaq.)

*  `:uid`: The privileged root login account (superuser) has the user ID 0.

*  `:gid`: This is the numeric primary group ID for this user. (Additional groups for the user are defined in the system group file; see `group(5)`).

*  `:gecos`: This field (sometimes called the “comment field”) is optional and used only for informational purposes. Usually, it contains the full username. Some programs (for example, `finger(1)`) display information from this field. GECOS stands for “General Electric Comprehensive Operating System”, which was renamed to GCOS when GE’s large systems division was sold to Honeywell. Dennis Ritchie has reported: “Sometimes we sent printer output or batch jobs to the GCOS machine. The gcos field in the password file was a place to stash the information for the $IDENTcard. Not elegant.”

*  `:dir`: This is the user’s home directory: the initial directory where the user is placed after logging in. The value in this field is used to set the HOME environment variable.

* `:shell`: This is the program to run at login (if empty, use /bin/sh). If set to a nonexistent executable, the user will be unable to login through `login(1)`. The value in this field is used to set the SHELL environment variable.


##### EtcUtils::Group

```ruby
EtcUtils.find_grp(1 || 'daemon')
EtcUtils::Group.find('daemon' || 1)
=> #<struct EtcUtils::Group name="daemon", passwd="x", gid=1, members=[]>
```

* `:name`: The name of the group.

* `:passwd`: The (encrypted) group password. If this field is empty, no password is needed.

* `:gid`: The numeric group ID.

* `:members`: A list of the usernames that are members of this group, separated by commas.

##### EtcUtils::Shadow

The user must be able to read `SHADOW` or nil is returned.

```ruby
SHADOW
=> "/etc/shadow"
EtcUtils.find_spwd(1 || 'daemon')
EtcUtils::Shadow.find('daemon' || 1)
=> #<struct EtcUtils::Shadow name="daemon", passwd="*", last_change=15729, min_change=0, max_change=99999, warn=7, inactive=-1, expire=-1, flag=-1>
```

*  `:name`: This is the user’s login name. It should not contain capital letters.

*  `:passwd`: Refer to crypt(3) for details on how this string is interpreted. If the password field contains some string that is not a valid result of crypt(3), for instance ! or *, the user will not be able to use a unix password to log in (but the user may log in the system by other means). This field may be empty, in which case no passwords are required to authenticate as the specified login name. However, some applications which read the /etc/shadow file may decide not to permit any access at all if the password field is empty. A password field which starts with a exclamation mark means that the password is locked. The remaining characters on the line represent the password field before the password was locked.

* `:last_change`:  The date of the last password change, expressed as the number of days since Jan 1, 1970. The value 0 has a special meaning, which is that the user should change her pasword the next time she will log in the system. An empty field means that password aging features are disabled.

* `:min_change`: The minimum password age is the number of days the user will have to wait before she will be allowed to change her password again. An empty field and value 0 mean that there are no minimum password age.

* `:max_change`: The maximum password age is the number of days after which the user will have to change her password. After this number of days is elapsed, the password may still be valid. The user should be asked to change her password the next time she will log in. An empty field means that there are no maximum password age, no password warning period, and no password inactivity period (see below). If the maximum password age is lower than the minimum password age, the user cannot change her password.

* `:warn`: The number of days before a password is going to expire (see the maximum password age above) during which the user should be warned. An empty field and value 0 mean that there are no password warning period.

* `:inactive`: The number of days after a password has expired (see the maximum password age above) during which the password should still be accepted (and the user should update her password during the next login). After expiration of the password and this expiration period is elapsed, no login is possible using the current user’s password. The user should contact her administrator. An empty field means that there are no enforcement of an inactivity period.

* `:expire`: The date of expiration of the account, expressed as the number of days since Jan 1, 1970. Note that an account expiration differs from a password expiration. In case of an acount expiration, the user shall not be allowed to login. In case of a password expiration, the user is not allowed to login using her password. An empty field means that the account will never expire. The value 0 should not be used as it is interpreted as either an account with no expiration, or as an expiration on Jan 1, 1970.

* `:flag`: This field is reserved for future use.


##### EtcUtils::GShadow

If you're having trouble with GShadow, even as root, please see [known issues](#known-issues).  Your nsswitch.conf file may contain a known bug.

The user must be able to read `GSHADOW` or nil is returned.

```ruby
GSHADOW
=> "/etc/gshadow"
EtcUtils.find_sgrp('daemon' || 1)
EtcUtils::GShadow.find('daemon' || 1)
EtcUtils::Gshadow.find('daemon' || 1)
=> #<struct EtcUtils::GShadow name="daemon", passwd="*", admins=[], members=[]>
```

* `:name`: It must be a valid group name, which exist on the system.

* `:passwd`: Refer to `crypt(3)` for details on how this string is interpreted. If the password field contains some string that is not a valid result of `crypt(3)`, for instance ! or *, users will not be able to use a unix password to access the group (but group members do not need the password). The password is used when an user who is not a member of the group wants to gain the permissions of this group (see `newgrp(1)`). This field may be empty, in which case only the group members can gain the group permissions. A password field which starts with a exclamation mark means that the password is locked. The remaining characters on the line represent the password field before the password was locked. This password supersedes any password specified in _/etc/group_.

* `:admins`: It must be a comma-separated list of user names. Administrators can change the password or the members of the group. Administrators also have the same permissions as the members (see below).

* `:members`: It must be a comma-separated list of user names. Members can access the group without being prompted for a password. You should use the same list of users as in _/etc/group_.


# Usage

## File locks

Passing a block to `EtcUtils.lock` is the preferred method of locking files, as unlock is always called regardless of exceptions

```ruby
> begin
>   lock {
>     puts "INSIDE BLOCK: #{locked?}"
>     raise "foobar"
>   }
> rescue
>   puts "RESCUED: #{locked?}"
> end
=> INSIDE BLOCK: true
=> RESCUED: false
``` 

`:lckpwdf` `:lock`: Locking files will return true if locked.  Calling lock on a locked file will return true.  A return of false indicates lock failure.

`:ulckpwdf` `:unlock`: Unlocking will return true upon success.  Subsequent calls against an unlocked file will return false.

To keep confusion at bay, calling `:locked?` will always return the true state of the lock.

```ruby
EtcUtils.lckpwdf
=> true
EtcUtils.lock
=> true
EtcUtils.lock
=> true
EtcUtils.locked?
=> true
EtcUtils.ulckpwdf
=> true
EtcUtils.ulckpwdf
=> false
EtcUtils.unlock
=> false
EtcUtils.locked?
=> false
```

---

The below should apply to any of the above structs.  If you find a bug, <b>please</b> open an issue.

XX can be replaced with

* pw # PASSWD
* gr  # GROUP
* sp # SHADOW
* sg # GSHADOW

## setXXent and getXXent

The `EtcUtils.setpwent` and `EtcUtils::Passwd.set` functions rewind to the beginning of the password database.

The `EtcUtils.endpwent` and `EtcUtils::Passwd.end` functions are used to close the password database after all processing has been performed.

Helper functions (literal 'XX') `EtcUtils.setXXent` and `EtcUtils.endXXent` rewind or close all database files.


## Retrieving Entries

`#set` is not required on the initial attempt at retrieving entries.

### getXXent

Calling `EtcUtils.getgrent` and `EtcUtils::Group.get` retrieves the first entry from the group database.

```ruby
EtcUtils.getgrent
=> #<struct EtcUtils::Group name="root", passwd="x", gid=0, members=[]>
...
EtcUtils::Group.get
=> #<struct EtcUtils::Group name="adm", passwd="x", gid=4, members=["ubuntu", "foobar"]>
EtcUtils.setgrent
=> nil
EtcUtils::Group.get
=> #<struct EtcUtils::Group name="root", passwd="x", gid=0, members=[]>
```

### find

`EtcUtils::GShadow.find` can be called with either a string or an integer.  In the case of shadow files, the corresponding etc file will be queried by uid/gid and returned.

```ruby
EtcUtils::GShadow.find 'adm'
=> #<struct EtcUtils::Group name="adm", passwd="x", gid=4, members=["ubuntu", "foobar"]>
EtcUtils::GShadow.find 4
=> #<struct EtcUtils::Group name="adm", passwd="x", gid=4, members=["ubuntu", "foobar"]>
```

## New Entries

### parse

If an entry already exists in the corresponding file, that object (un-altered) is returned.

```ruby
p = EtcUtils::Passwd.find 1
=> #<struct EtcUtils::Passwd name="daemon", passwd="x", uid=1, gid=1, gecos="daemon", dir="/usr/sbin", shell="/bin/sh">
p.uid = 9999
=> 9999
p.to_s
=> "daemon:x:9999:1:daemon:/usr/sbin:/bin/sh"
EtcUtils::Passwd.parse(p.to_s)
=> #<struct EtcUtils::Passwd name="daemon", passwd="x", uid=1, gid=1, gecos="daemon", dir="/usr/sbin", shell="/bin/sh">
```

If no entry is found, the new object is returned.

If uid/gid fields are left blank, the next available id is returned.

```ruby
EtcUtils::Passwd.parse("foobar:x:::Foobar User:/home/foobar:/bin/shell")
=> #<struct EtcUtils::Passwd name="foobar", passwd="x", uid=11, gid=11, gecos="Foobar User", dir="/home/foobar", shell="/bin/shell">
```
### new

When called without args, an empty struct is returned.  When called with args, those args are used to populate the object.

```ruby
EtcUtils::GShadow.new("foobar", '!', nil, ['sudo','adm'])
=> #<struct EtcUtils::GShadow name="foobar", passwd="!", admins=nil, members=["sudo", "adm"]>
EtcUtils::GShadow.new
=> #<struct EtcUtils::GShadow name=nil, passwd=nil, admins=nil, members=nil>
```
## Writing Entries

**Please be careful when you're writing to user database files.**

Before writing to any file, you should first create a backup.  Conventional nomenclature is to append a dash to the end of the string.  You'll also need you preserve file permissions.  See `File.stat`.

```ruby
GSHADOW + '-'
=> "/etc/gshadow-"

stat = File.stat(GSHADOW).dup
File.open(GSHADOW + '-', 'w+', 0600) { |bf| bf.puts IO.readlines(GSHADOW) }

if stat.size !=  File.stat(GSHADOW + '-').size
  raise_retry "#{GSHADOW} backup error"
end
```

To update etc files, you should write all entries, including your updates, first to a temp file.

```ruby
tmp = "/etc/_#{SHADOW.split('/').last}"
fh = File.open(SHADOW, 'r')

EtcUtils.lock {
  File.open(tmp, File::RDWR|File::CREAT, 0600) { |tmp_fh|
    while ( ent = EtcUtils::Shadow.get )
      ent.fputs(tmp_fh)
    end
  }
}
fh.close
```

## Next UID/GID

`:next_uid` will store and increment the next available uid.  Each time next_uid is called, that counter is incremented to the next available.

`:next_gid` will store and increment the next available gid.  Each time next_gid is called, that counter is incremented to the next available.

```ruby
EtcUtils.next_uid = 12
=> 12
EtcUtils.next_uid
=> 12
EtcUtils.next_uid
=> 14
```

 `:parse` assigns `:next_uid` to `:next_gid` then confirmed as available.  This attempts uid/gid in sync for new users.


```ruby
EtcUtils.next_uid  = 1000
=> 1000
EtcUtils::Passwd.parse("foobar:x:::Foobar User:/home/foobar:/bin/shell")
=> #<struct EtcUtils::Passwd name="foobar", passwd="x", uid=1016, gid=1016, gecos="Foobar User", dir="/home/foobar", shell="/bin/shell">
```

Although, when calling `:next_uid` or `:next_gid` they are not kept in sync.  When creating new entries, it's recommended allow parse or new to manage uid/gids rather than assigning them yourself.

```ruby
EtcUtils.next_uid = 19
=> 19
EtcUtils.next_gid
=> 1017
```