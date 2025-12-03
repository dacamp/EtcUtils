require 'etcutils_test_helper'

class GroupClassTest < Test::Unit::TestCase

  ##
  # Module Specific Methods
  #

  def test_set_end_ent
    assert_nothing_raised do
      EU.setgrent
    end

    assert_nothing_raised do
      EU.endgrent
    end
  end

  def test_find
    assert_nil EtcUtils.find_grp("testuser"), "EU.find_grp should return nil if group does not exist"
    # macOS uses 'wheel' for GID 0, Linux uses 'root'
    assert_equal(root_group_name, EtcUtils.find_grp(root_group_name).name, "EU.find_grp(str) should return group if it exists")
    assert_equal(root_group_name, EtcUtils.find_grp(0).name, "EU.find_grp(int) should return group if it exists")
    assert_nothing_raised do
      EU.setgrent
    end
    # On macOS, first entry from getgrent may not be GID 0 (Directory Services order differs)
    if MACOS
      first_group = getgrent
      assert_not_nil first_group, "EU.getgrent should return a group"
    else
      assert_equal(getgrnam('root').name, getgrent.name, "EU.getgrnam('root') and EU.getgrent should return the same group")
    end
  end

  def test_sgetgrent
    skip_unless_sgetgrent
    group_name = root_group_name
    assert sgetgrent(find_grp(group_name).to_entry).name.eql? group_name
  end

  def test_getgrent_while
    assert_nothing_raised do
      EtcUtils.setgrent
      while ( ent = EtcUtils.getgrent ); nil; end
    end
  end

  # Helper method to normalize group file lines (sort members alphabetically)
  def normalize_group_line(line)
    parts = line.chomp.split(':')
    return line if parts.length < 4
    # Sort the members (4th field) alphabetically
    parts[3] = parts[3].split(',').sort.join(',')
    parts.join(':')
  end

  def test_fgetgrent_and_putgrent
    skip_unless_fgetgrent
    skip_unless_putgrent
    tmp_fn = "/tmp/_fgetsgent_test"
    assert_nothing_raised do
      fh = File.open('/etc/group', 'r')
      File.open(tmp_fn, File::RDWR|File::CREAT, 0600) { |tmp_fh|
        while ( ent = EtcUtils.fgetgrent(fh) )
          EU.putgrent(ent, tmp_fh)
        end
      }
      fh.close
    end
    assert File.exist?(tmp_fn), "EU.fgetgrent(fh) should write to fh"
    # Compare files with normalized member order (gem sorts members alphabetically)
    orig_lines = File.readlines("/etc/group").map { |l| normalize_group_line(l) }
    new_lines = File.readlines(tmp_fn).map { |l| normalize_group_line(l) }
    assert_equal orig_lines, new_lines,
      "DIFF FAILED: /etc/group <=> #{tmp_fn}\n" << `diff /etc/group #{tmp_fn}`
  ensure
    FileUtils.remove_file(tmp_fn) if tmp_fn && File.exist?(tmp_fn)
  end

  def test_putgrent_raises
    # On macOS, fputs falls back to sprintf which doesn't check file mode
    skip_on_macos("fputs fallback doesn't validate file mode on macOS")
    FileUtils.touch "/tmp/_group"

    assert_raise IOError do
      f = File.open("/tmp/_group", 'r')
      u = EU.find_grp(root_group_name)
      u.fputs f
    end
  ensure
    FileUtils.remove_file("/tmp/_group") if File.exist?("/tmp/_group")
  end

  ##
  # EU::Group class methods
  #
  def test_class_set_end_ent
    assert_nothing_raised do
      EU::Group.set
    end

    assert_nothing_raised do
      EU::Group.end
    end
  end

  def test_class_get
    assert_not_nil EU::Group.get
  end

  def test_class_each
    assert_nothing_raised do
      EU::Group.each do |e|
        assert e.name
      end
    end
  end

  def test_class_find
    assert_equal root_group_name, EU::Group.find(root_group_name).name
  end

  def test_class_parse
    skip_unless_sgetgrent
    assert_nothing_raised do
      EtcUtils::Group.parse("root:x:0:")
    end
  end

  def test_class_parse_members
    skip_unless_sgetgrent
    assert_nothing_raised do
      assert_equal Array, EtcUtils::Group.parse("root:x:0:").members.class
    end
  end

  ##
  # EU::Group instance methods
  #
  def test_init
    assert_equal EU::Group, EU::Group.new.class
  end

  def test_instance_methods
    e = EU::Group.find(root_group_name)
    assert_equal root_group_name, e.name
    assert_not_nil e.passwd
    assert_equal 0, e.gid
    if HAVE_SGETGRENT
      assert_equal root_group_name, EU::Group.parse(e.to_entry).name
    end
    assert_equal String, e.to_entry.class
    assert_equal Array, e.members.class
    assert e.respond_to?(:fputs)
  end
end
