$:.unshift File.dirname(__FILE__) + "/../lib"

require 'test/unit'
require 'etcutils'

$eu_user = EtcUtils.me.uid.zero? ? "root" : "user"

# Platform detection
MACOS = RUBY_PLATFORM =~ /darwin/
LINUX = RUBY_PLATFORM =~ /linux/

# Features not available on macOS
HAVE_FGETPWENT = EU.respond_to?(:fgetpwent)
HAVE_FGETGRENT = EU.respond_to?(:fgetgrent)
HAVE_SGETPWENT = EU.respond_to?(:sgetpwent)
HAVE_SGETGRENT = EU.respond_to?(:sgetgrent)
HAVE_PUTPWENT = EU.respond_to?(:putpwent)
HAVE_PUTGRENT = EU.respond_to?(:putgrent)
HAVE_LOCKING = EU.can_lockfile?
HAVE_SHADOW = defined?(EU::SHADOW) && File.exist?(EU::SHADOW)
HAVE_GSHADOW = defined?(EU::GSHADOW) && File.exist?(EU::GSHADOW)

# On macOS, root user is UID 0 but first entry from getpwent may not be root
# On Linux, root is typically the first entry
def first_user_is_root?
  EU.setpwent
  first = EU.getpwent
  EU.endpwent
  first&.uid == 0
end

def first_group_is_root?
  EU.setgrent
  first = EU.getgrent
  EU.endgrent
  first&.gid == 0
end

# macOS uses 'wheel' as GID 0, Linux uses 'root'
def root_group_name
  MACOS ? 'wheel' : 'root'
end

class Test::Unit::TestCase
  include EtcUtils

  def skip_on_macos(reason = "Not supported on macOS")
    omit(reason) if MACOS
  end

  def skip_unless_fgetpwent
    omit("fgetpwent not available") unless HAVE_FGETPWENT
  end

  def skip_unless_fgetgrent
    omit("fgetgrent not available") unless HAVE_FGETGRENT
  end

  def skip_unless_sgetpwent
    omit("sgetpwent not available") unless HAVE_SGETPWENT
  end

  def skip_unless_sgetgrent
    omit("sgetgrent not available") unless HAVE_SGETGRENT
  end

  def skip_unless_putpwent
    omit("putpwent not available") unless HAVE_PUTPWENT
  end

  def skip_unless_putgrent
    omit("putgrent not available") unless HAVE_PUTGRENT
  end

  def skip_unless_locking
    omit("File locking not available") unless HAVE_LOCKING
  end
end
