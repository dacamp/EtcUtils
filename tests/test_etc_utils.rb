require 'etcutils_test_helper'

class EtcUtilsTest < Test::Unit::TestCase
  SG_MAP = {
    :pw => { :file => PASSWD,  :ext => 'd'  },
    :sp => { :file => SHADOW,  :ext => 'wd' },
    :gr => { :file => GROUP,   :ext => 'p'  },
    :sg => { :file => GSHADOW, :ext => 'rp' },
  }

  def test_locking
    assert_block "Couldn't run a block inside of lock()" do
      lock { assert locked? }
      !locked?
    end
  end

  def test_locked_after_exception
    assert_block "Files remained locked when an exception is raised inside of lock()" do
      begin
        lock { raise "foobar" }
      rescue
        !locked?
      end
    end
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
      tmp_fn = "/tmp/_fget#{xx}ent_test"
      assert_nothing_raised do
        fh = File.open(SG_MAP[xx][:file], 'r')
        File.open(tmp_fn, File::RDWR|File::CREAT, 0600) { |tmp_fh|
          while ( ent = EtcUtils.send("fget#{xx}ent", fh) )
            ent.fputs(tmp_fh)
          end
        }
        fh.close
        assert FileUtils.compare_file(SG_MAP[xx][:file], tmp_fn) == true
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
    assert sgetspent(find_spwd('root').to_s).name.eql? "root"
    assert sgetsgent(find_sgrp('root').to_s).name.eql? "root"
  end
end
