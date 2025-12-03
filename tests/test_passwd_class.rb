require 'etcutils_test_helper'

class PasswdClassTest < Test::Unit::TestCase


  ##
  # Module Specific Methods
  #

  def test_set_end_ent
    assert_nothing_raised do
      EU.setpwent
    end

    assert_nothing_raised do
      EU.endpwent
    end
  end

  def test_find
    assert_nil EtcUtils.find_pwd("testuser"), "EU.find_pwd should return nil if user does not exist"
    assert_equal("root", EtcUtils.find_pwd("root").name, "EU.find_pwd(str) should return user if it exists")
    assert_equal("root", EtcUtils.find_pwd(0).name, "EU.find_pwd(int) should return user if it exists")
    assert_nothing_raised do
      EU.setpwent
    end
    assert_equal(getpwnam('root').name, getpwent.name, "EU.getpwnam('root') and EU.getpwent should return the same user")
  end

  def test_sgetpwent
    assert sgetpwent(find_pwd('root').to_entry).name.eql? "root"
  end

  def test_getpwent_while
    assert_nothing_raised do
      EtcUtils.setpwent
      while ( ent = EtcUtils.getpwent ); nil; end
    end
  end

  def test_fgetpwent_and_putpwent
    tmp_fn = "/tmp/_fgetsgent_test"
    assert_nothing_raised do
      fh = File.open('/etc/passwd', 'r')
      File.open(tmp_fn, File::RDWR|File::CREAT, 0600) { |tmp_fh|
        while ( ent = EtcUtils.fgetpwent(fh) )
          EU.putpwent(ent, tmp_fh)
        end
      }
      fh.close
    end
    assert File.exist?(tmp_fn), "EU.fgetpwent(fh) should write to fh"
    assert FileUtils.compare_file("/etc/passwd", tmp_fn) == true,
      "DIFF FAILED: /etc/passwd <=> #{tmp_fn}\n" << `diff /etc/passwd #{tmp_fn}`
  ensure
    FileUtils.remove_file(tmp_fn);
  end

  def test_putpwent_raises
    FileUtils.touch "/tmp/_passwd"

    assert_raise IOError do
      f = File.open("/tmp/_passwd", 'r')
      u = EU.find_pwd('root')
      u.fputs f
    end
  ensure
    FileUtils.remove_file("/tmp/_passwd");
  end

  ##
  # EU::Passwd class methods
  #
  def test_class_set_end_ent
    assert_nothing_raised do
      EU::Passwd.set
    end

    assert_nothing_raised do
      EU::Passwd.end
    end
  end

  def test_class_get
    assert_not_nil EU::Passwd.get
  end

  def test_class_each
    assert_nothing_raised do
      EU::Passwd.each do |e|
        assert e.name
      end
    end
  end

  def test_class_find
    assert_equal "root", EU::Passwd.find('root').name
  end

  def test_class_parse
    assert_nothing_raised do
      EtcUtils::Passwd.parse("root:x:0:0:root:/root:/bin/bash")
    end
  end

  ##
  # EU::Passwd instance methods
  #
  def test_init
    assert_equal EU::Passwd, EU::Passwd.new.class
  end

  def test_instance_methods
    e = EU::Passwd.find('root')
    assert_equal 'root', e.name
    assert_not_nil e.passwd
    assert_equal 0, e.uid
    assert_equal 0, e.gid
    assert_equal '/root', e.directory
    assert_not_nil e.shell
    assert e.respond_to?(:fputs)
    assert_equal 'root', EU::Passwd.parse(e.to_entry).name
    assert_equal String, e.to_entry.class
  end
end
