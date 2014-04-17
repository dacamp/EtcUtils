require 'etcutils_test_helper'

class EtcUtilsTest < Test::Unit::TestCase
  SG_MAP = Hash.new.tap do |h|
    if $root
      h[:sp] = { :file => SHADOW,  :ext => 'wd' }
      h[:sg] = { :file => GSHADOW, :ext => 'rp' }
    end
    h[:pw] = { :file => PASSWD,  :ext => 'd'  }
    h[:gr] = { :file => GROUP,   :ext => 'p'  }
  end

  def test_constants
    assert_equal(EtcUtils, EU)
    assert_equal('1.0.0', EU::VERSION)

    # User DB Files
    [:passwd, :group, :shadow, :gshadow].each do |m|
      a = m.to_s.downcase
      if File.exists?(f = "/etc/#{a}")
        assert_equal(eval("EU::#{m.upcase.to_s}"), f)
        assert EU.send("has_#{a}?".to_sym), "EtcUtils.has_#{a}? should be true."
      end
    end

    assert_equal(EU::SHELL, '/bin/bash')
    assert_equal(EU.me.uid, EU.getlogin.uid)
  end

  def test_nsswitch_conf_gshadow
    assert_block "\n#{'*' * 75}
nsswitch.conf may be misconfigured. Consider adding the below to /etc/nsswitch.conf.
gshadow:\tfiles
See 'http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=699089' for more.\n" do
      setsgent
      !!getsgent
    end
  end

  SG_MAP.keys.each do |xx|
    define_method("test_fget#{xx}ent_cp#{SG_MAP[xx][:file].gsub('/','_')}")  {
      begin
        tmp_fn = "/tmp/_fget#{xx}ent_test"
        assert_nothing_raised do
          fh = File.open(SG_MAP[xx][:file], 'r')
          File.open(tmp_fn, File::RDWR|File::CREAT, 0600) { |tmp_fh|
            while ( ent = EtcUtils.send("fget#{xx}ent", fh) )
              ent.fputs(tmp_fh)
            end
          }
          fh.close
          assert FileUtils.compare_file(SG_MAP[xx][:file], tmp_fn) == true, "DIFF FAILED: #{SG_MAP[xx][:file]} <=> #{tmp_fn}\n" << `diff #{SG_MAP[xx][:file]} #{tmp_fn}`
        end
      ensure
        FileUtils.remove_file(tmp_fn);
      end
    }

    define_method("test_get#{xx}") {
      assert_nothing_raised do
        EtcUtils.send("set#{xx}ent")
        while ( ent = EtcUtils.send("get#{xx}ent")); nil; end
      end
    }

    m = "find_#{xx}#{SG_MAP[xx][:ext]}"
    define_method("test_#{m}_typeerr")  { assert_raise TypeError do; EtcUtils.send(m,{}); end }
    define_method("test_#{m}_find_int") { assert EtcUtils.send(m, 0).name.eql? "root"  }
    define_method("test_#{m}_find_str") { assert EtcUtils.send(m, 'root').name.eql? "root"  }
  end

  def test_sgetXXent
    assert sgetspent(find_spwd('root').to_entry).name.eql? "root"
    assert sgetsgent(find_sgrp('root').to_entry).name.eql? "root"
    assert sgetgrent(find_grp('root').to_entry).name.eql? "root"
    assert sgetpwent(find_pwd('root').to_entry).name.eql? "root"
  end
end
