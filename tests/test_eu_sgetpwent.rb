require 'etcutils_test_helper'

class EUsgetpwentTest < Test::Unit::TestCase

  def setup
    @uid = 9999
    @username = "testuser#{@uid}"

    @taken_uid = EU.getpwent.uid
    @taken_gid = EU.getgrent.gid
  end

  # Test that parsing an existing user's entry returns exactly what was passed
  def test_eu_known_sgetpwent
    r = find_pwd(0).to_entry
    assert_equal(r, sgetpwent(r).to_entry, "EU.sgetpwent(r) should equal (r = find_pwd(x).to_entry)")
  end

  # Test that attribute changes are preserved exactly as given
  def test_eu_changed_sgetpwent
    r = find_pwd(0)
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

  # Test that new user entries are parsed exactly as given - no auto-assignment
  def test_eu_new_sgetpwent
    new = "#{@username}:x:#{@uid}:#{@uid}:Test User:/home/testuser:/bin/bash"

    ent = EU.sgetpwent(new)
    assert_equal(@username, ent.name, "EU.sgetpwent should have the same name")
    assert_equal(@uid, ent.uid, "EU.sgetpwent should return exactly the UID provided")
    assert_equal(@uid, ent.gid, "EU.sgetpwent should return exactly the GID provided")
    assert_equal("Test User", ent.gecos, "EU.sgetpwent should return exactly the gecos provided")
    assert_equal("/home/testuser", ent.directory, "EU.sgetpwent should return exactly the directory provided")
    assert_equal("/bin/bash", ent.shell, "EU.sgetpwent should return exactly the shell provided")
  end

  # Test that empty UID/GID fields become 0
  def test_eu_empty_uid_gid_sgetpwent
    new = "#{@username}:x:::Test User:/home/testuser:/bin/bash"

    ent = EU.sgetpwent(new)
    assert_equal(@username, ent.name, "EU.sgetpwent should have the same name")
    assert_equal(0, ent.uid, "EU.sgetpwent should return 0 for empty UID")
    assert_equal(0, ent.gid, "EU.sgetpwent should return 0 for empty GID")
  end

  # Test that empty string fields become empty strings
  # Format: name:passwd:uid:gid:gecos:dir:shell (7 fields)
  def test_eu_empty_string_fields_sgetpwent
    new = "#{@username}:::::/home/testuser:/bin/sh"

    ent = EU.sgetpwent(new)
    assert_equal(@username, ent.name, "EU.sgetpwent should have the same name")
    assert_equal("", ent.passwd, "EU.sgetpwent should return empty string for empty passwd")
    assert_equal("", ent.gecos, "EU.sgetpwent should return empty string for empty gecos")
    assert_equal("/bin/sh", ent.shell, "EU.sgetpwent should parse shell correctly")
  end

  def test_eu_raise_sgetpwent
    assert_raise ArgumentError do
      EU.sgetpwent(":x:1000:1000:Test User:/home/testuser:/bin/bash")
    end
  end

  # Test that conflicting UIDs/GIDs are returned exactly as given (pure parsing)
  def test_eu_conflict_sgetpwent
    new = "#{@username}:x:#{@taken_uid}:#{@taken_gid}:Test User:/home/testuser:/bin/bash"
    ent = EU.sgetpwent(new)
    # Pure parser returns exactly what was passed - no conflict resolution
    assert_equal(@taken_uid, ent.uid, "EU.sgetpwent should return exactly the UID provided (no conflict resolution)")
    assert_equal(@taken_gid, ent.gid, "EU.sgetpwent should return exactly the GID provided (no conflict resolution)")
  end
end
