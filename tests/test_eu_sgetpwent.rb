require 'etcutils_test_helper'

module EUGetPW
  def self.uid
    @free_uid ||= EUGetPW._free_uid
  end

  def self._free_uid
    id = 9999
    while EU.find_pwd(id) || EU.find_grp(id)
      id+=1
    end
    return id
  end
end

class EUsgetpwentTest < Test::Unit::TestCase
  include EUGetPW

  def setup
    @uid = EUGetPW.uid
    @username = "testuser#{@uid}"

    @taken_uid = EU.getpwent.uid
    @taken_gid = EU.getgrent.gid
    @diff_ids = [@username, "x", @taken_uid, @taken_gid, "Test User", "/home/testuser", "/bin/bash"]
  end

  def test_eu_known_sgetpwent
    r = find_pwd(0).to_entry
    assert_equal(r, sgetpwent(r).to_entry, "EU.sgetpwent(r) should equal (r = find_pwd(x).to_entry)")
  end

  def test_eu_changed_sgetpwent
    r = find_pwd(0)
    r.gecos = "Not #{r.gecos || r.name}"
    r.directory = "/home/etc_utils"
    r.passwd = "password"
    r.shell  = "/bin/false"
    ent = sgetpwent(r.to_entry)
    assert_not_equal(find_pwd(0).to_entry, ent.to_entry, "EU.sgetpwent should respect most attribute changes")
    assert_equal(r.gecos, ent.gecos, "EU.sgetpwent should respect #gecos changes")
    assert_equal(r.directory, ent.directory, "EU.sgetpwent should respect #directory changes")
    assert_equal(r.passwd, ent.passwd, "EU.sgetpwent should respect #directory changes")
    assert_equal(r.shell, ent.shell, "EU.sgetpwent should respect #shell changes")
  end

  def test_eu_new_sgetpwent
    if RUBY_PLATFORM =~ /darwin/    
      new = "#{@username}:*:#{EUGetPW.uid}:#{EUGetPW.uid}::0:0:Test User:/home/testuser:/bin/bash"
    else
      new = "#{@username}:x:#{EUGetPW.uid}:#{EUGetPW.uid}:Test User:/home/testuser:/bin/bash"
    end

    ent = EU.sgetpwent(new)
    assert_equal(@username, ent.name, "EU.sgetpwent should have the same name")
    assert_equal(@uid, ent.uid, "EU.sgetpwent should return UID when available")
    assert_equal(@uid, ent.gid, "EU.sgetpwent should return GID when available")
  end

  def test_eu_raise_sgetpwent
    assert_raise ArgumentError do
      if RUBY_PLATFORM =~ /darwin/
        EU.sgetpwent(":*:1000:1000::0:0:Test User:/home/testuser:/bin/bash")
      else
        EU.sgetpwent(":x:1000:1000:Test User:/home/testuser:/bin/bash")
      end
    end

    # Should raise rb_eSystemCallError if system calls fail (see README)
    #
    #assert_raise Errno::ENOENT do
    #  EU.sgetpwent("testuser:x:1000:1000:Test User:/fake/path/testuser:/bin/bash")
    #end
  end

  def test_eu_conflict_sgetpwent
    if RUBY_PLATFORM =~ /darwin/
      new = "testuser:*:#{@taken_uid}:#{@taken_gid}::0:0:Test User:/Users/test:/bin/bash"
    else
      new = @diff_ids.join(":")
    end
    ent = EU.sgetpwent(new)
    assert_not_equal(@taken_uid, ent.uid, "EU.sgetpwent should return next availabile UID when conflict")
    assert_not_equal(@taken_gid, ent.gid, "EU.sgetpwent should return next availabile GID when conflict")
  end
end
