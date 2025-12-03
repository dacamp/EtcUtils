class ShadowTest < Test::Unit::TestCase
  require 'stringio'
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

  def test_fgetspent_and_putspent
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
    assert File.exist?(tmp_fn), "EU.fgetspent(fh) should write to fh"
    assert FileUtils.compare_file("/etc/shadow", tmp_fn) == true,
      "DIFF FAILED: /etc/shadow <=> #{tmp_fn}\n" << `diff /etc/shadow #{tmp_fn}`
  ensure
    FileUtils.remove_file(tmp_fn);
  end

  def test_putspent_raises
    FileUtils.touch "/tmp/_shadow"

    assert_raise IOError do
      f = File.open("/tmp/_shadow", 'r')
      u = EU.find_spwd('root')
      u.fputs f
    end
  ensure
    FileUtils.remove_file("/tmp/_shadow");
  end

  ##
  # EU::Shadow class methods
  #
  def test_class_set_end_ent
    assert_nothing_raised do
      EU::Shadow.set
    end

    assert_nothing_raised do
      EU::Shadow.end
    end
  end

  def test_class_get
    assert_not_nil EU::Shadow.get
  end

  def test_class_each
    assert_nothing_raised do
      EU::Shadow.each do |e|
        assert e.name
      end
    end
  end

  def test_class_find
    assert_equal "root", EU::Shadow.find('root').name
  end

  def test_class_parse
    assert_nothing_raised do
      EtcUtils::Shadow.parse("root:!:16122:0:99999:7:::")
    end
  end

  ##
  # EU::Shadow instance methods
  #
  def test_init
    assert_equal EU::Shadow, EU::Shadow.new.class
  end

  def test_instance_methods
    e = EU::Shadow.find('root')
    assert_equal 'root', e.name
    assert_not_nil e.passwd
    assert_not_nil e.last_pw_change
    assert e.respond_to?(:fputs)
    assert_equal 'root', EU::Shadow.parse(e.to_entry).name
    assert_equal String, e.to_entry.class
  end

#  rb_define_method(rb_cShadow, "passwd=", user_set_pw_change, 1);
#  rb_define_method(rb_cShadow, "last_pw_change_date", user_get_pw_change, 0);
#  rb_define_method(rb_cShadow, "expire_date", user_get_expire, 0);
#  rb_define_method(rb_cShadow, "expire_date=", user_set_expire, 1);
  def test_last_pwchange
    e = EU::Shadow.find('root')
    lstchg = e.last_pw_change
    e.passwd = "!#{e.passwd}"
    assert_not_equal e.last_pw_change, lstchg
  end

  def test_expire
    e = EU::Shadow.find('root')
    assert_not_nil e.expire = 500
    assert_equal Time.at(500 * 86400), e.expire_date
    n = Time.now
    assert_not_nil e.expire = n
    assert_equal n.to_i / 86400, e.expire
  end

  def test_expire_warning
    e = EU::Shadow.find('root')
    assert_equal capture_stderr{  e.expire = 0 }.gsub(/.+warning:\s+|\n/,''), "Setting EtcUtils::Shadow#expire to 0 should not be used as it is interpreted as either an account with no expiration, or as an expiration of Jan 1, 1970."
    assert_equal 0, e.expire
  end

  def capture_stderr
    # The output stream must be an IO-like object. In this case we capture it in
    # an in-memory IO object so we can return the string value. You can assign any
    # IO object here.
    previous_stderr, $stderr = $stderr, StringIO.new
    yield
    $stderr.string
  ensure
    # Restore the previous value of stderr (typically equal to STDERR).
    $stderr = previous_stderr
  end
end
