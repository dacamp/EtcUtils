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
    assert_nil EtcUtils.find_grp("testuser"), "EU.find_grp should return nil if user does not exist"
    assert_equal("root", EtcUtils.find_grp("root").name, "EU.find_grp(str) should return user if it exists")
    assert_equal("root", EtcUtils.find_grp(0).name, "EU.find_grp(int) should return user if it exists")
    assert_nothing_raised do
      EU.setgrent
    end
    assert_equal(getgrnam('root').name, getgrent.name, "EU.getgrnam('root') and EU.getgrent should return the same user")
  end

  def test_sgetgrent
    assert sgetgrent(find_grp('root').to_entry).name.eql? "root"
  end

  def test_getgrent_while
    assert_nothing_raised do
      EtcUtils.setgrent
      while ( ent = EtcUtils.getgrent ); nil; end
    end
  end

  def test_fgetgrent_and_putgrent
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
    assert File.exists?(tmp_fn), "EU.fgetgrent(fh) should write to fh"
    assert FileUtils.compare_file("/etc/group", tmp_fn) == true,
      "DIFF FAILED: /etc/group <=> #{tmp_fn}\n" << `diff /etc/group #{tmp_fn}`
  ensure
    FileUtils.remove_file(tmp_fn);
  end

  def test_putgrent_raises
    FileUtils.touch "/tmp/_group"

    assert_raise IOError do
      f = File.open("/tmp/_group", 'r')
      u = EU.find_grp('root')
      u.fputs f
    end
  ensure
    FileUtils.remove_file("/tmp/_group");
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
    assert_equal "root", EU::Group.find('root').name
  end

  def test_class_parse
    assert_nothing_raised do
      EtcUtils::Group.parse("root:x:0:")
    end
  end

  def test_class_parse_members
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
    e = EU::Group.find('root')
    assert_equal 'root', e.name
    assert_not_nil e.passwd
    assert_equal 0, e.gid
    assert_equal 'root', EU::Group.parse(e.to_entry).name
    assert_equal String, e.to_entry.class
    assert_equal Array, e.members.class
    assert e.respond_to?(:fputs)
  end
end
