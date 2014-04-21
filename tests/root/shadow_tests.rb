class ShadowTest < Test::Unit::TestCase


  ##
  # Module Specific Methods
  #

  def test_set_end_ent
    assert_nothing_raised do
      EU.setspent
    end

    assert_nothing_raised do
      EU.endspent
    end
  end

  def test_find
    assert_nil EtcUtils.find_spwd("testuser"), "EU.find_spwd should return nil if user does not exist"
    assert_equal("root", EtcUtils.find_spwd("root").name, "EU.find_spwd(str) should return user if it exists")
    assert_equal("root", EtcUtils.find_spwd(0).name, "EU.find_spwd(int) should return user if it exists")
    assert_nothing_raised do
      EU.setspent
    end
    assert_equal(getspnam('root').name, getspent.name, "EU.getspent and EU.find_spwd(0) should return the same user")
  end

  def test_shadow_vs_passwd
    assert_equal(find_spwd('root').name, find_pwd('root').name, "EU.find_spwd and EU.find_pwd should return the same user")
  end

  def test_sgetspent
    assert EU.sgetspent(EU.find_spwd('root').to_entry).name.eql? "root"
  end

  def test_getspent_while
    assert_nothing_raised do
      EtcUtils.setspent
      while ( ent = EtcUtils.getspent ); nil; end
    end
  end

  def test_fgetspent_and_fputs
    tmp_fn = "/tmp/_fgetsgent_test"
    assert_nothing_raised do
      fh = File.open('/etc/shadow', 'r')
      File.open(tmp_fn, File::RDWR|File::CREAT, 0600) { |tmp_fh|
        while ( ent = EtcUtils.fgetspent(fh) )
          EU.putspent(ent, tmp_fh)
        end
      }
      fh.close
    end
    assert File.exists?(tmp_fn), "EU::Shadow#fputs(fh) should write to fh"
    assert FileUtils.compare_file("/etc/shadow", tmp_fn) == true,
      "DIFF FAILED: /etc/shadow <=> #{tmp_fn}\n" << `diff /etc/shadow #{tmp_fn}`
  ensure
    FileUtils.remove_file(tmp_fn);
  end

  ##
  # EU::Shadow class methods
  #
end
