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
  end

  def test_eu_known_sgetpwent
    r = find_pwd(0).to_entry
    assert_equal(r, sgetpwent(r).to_entry, "EU.sgetpwent(r) should equal (r = find_pwd(x).to_entry)")
  end

  def test_eu_changed_sgetpwent
    r = find_pwd(0)
    # Capture original values before modification since sgetpwent may modify
    # static storage that find_pwd also uses
    original_entry = find_pwd(0).to_entry.dup
    r.gecos = "Not #{r.gecos || r.name}"
    r.directory = "/home/etc_utils"
    r.passwd = "password"
    r.shell  = "/bin/false"
    ent = sgetpwent(r.to_entry)
    assert_not_equal(original_entry, ent.to_entry, "EU.sgetpwent should respect most attribute changes")
    assert_equal(r.gecos, ent.gecos, "EU.sgetpwent should respect #gecos changes")
    assert_equal(r.directory, ent.directory, "EU.sgetpwent should respect #directory changes")
    assert_equal(r.passwd, ent.passwd, "EU.sgetpwent should respect #passwd changes")
    assert_equal(r.shell, ent.shell, "EU.sgetpwent should respect #shell changes")
  end

  def test_eu_new_sgetpwent
    new = "#{@username}:x:#{EUGetPW.uid}:#{EUGetPW.uid}:Test User:/home/testuser:/bin/bash"

    ent = EU.sgetpwent(new)
    assert_equal(@username, ent.name, "EU.sgetpwent should have the same name")
    assert_equal(@uid, ent.uid, "EU.sgetpwent should return UID when available")
    assert_equal(@uid, ent.gid, "EU.sgetpwent should return GID when available")

    ent = EU.sgetpwent(new.gsub(/#{EUGetPW.uid}/,''))
    e = EU.next_uid(9999) - 1
    assert_equal(e, ent.uid, "EU.sgetpwent should return UID when available")
    assert_equal(e, ent.gid, "EU.sgetpwent should return GID when available")
  end

  def test_eu_raise_sgetpwent
    assert_raise ArgumentError do
      EU.sgetpwent(":x:1000:1000:Test User:/home/testuser:/bin/bash")
    end

    # Should raise rb_eSystemCallError if system calls fail (see README)
    #
    #assert_raise Errno::ENOENT do
    #  EU.sgetpwent("testuser:x:1000:1000:Test User:/fake/path/testuser:/bin/bash")
    #end
  end

  def test_eu_conflict_sgetpwent
    new = "#{@username}:x:#{@taken_uid}:#{@taken_gid}:Test User:/home/testuser:/bin/bash"
    ent = EU.sgetpwent(new)
    assert_not_equal(@taken_uid, ent.uid, "EU.sgetpwent should return next availabile UID when conflict")
    # GID behavior depends on the value:
    # - GID 0: NOT preserved (gets next available GID)
    # - GIDs 1-999: preserved (system GIDs)
    # - GIDs >= 1000: NOT preserved (gets next available GID)
    if @taken_gid > 0 && @taken_gid < 1000
      assert_equal(@taken_gid, ent.gid, "EU.sgetpwent preserves system GIDs (1-999)")
    else
      assert_not_equal(@taken_gid, ent.gid, "EU.sgetpwent should return next available GID when conflict (GID 0 or >= 1000)")
    end
  end
end
