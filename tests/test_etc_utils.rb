require 'locksmith_test_helper'

class EtcUtilsTest < Test::Unit::TestCase
  include EtcUtils

  FIND_CMDS = [:find_pwd, :find_spwd, :find_grp, :find_sgrp]

  def test_etc_locking
    assert_block "Couldn't run a block inside of lock()" do
      lock { assert locked? }
      !locked?
    end
  end

  def test_etc_utils_locked_raise
    assert_block "Files remained locked when an exception is raised inside of lock()" do
      begin
        lock { raise "foobar" }
      rescue
        !locked?
      end
    end
  end

  FIND_CMDS.each do |m|
    define_method("test_#{m.to_s}_typeerr")  { assert_raise TypeError do; EtcUtils.send(m,{}); end }
    define_method("test_#{m.to_s}_find_int") { assert EtcUtils.send(m, 0).name.eql? "root"  }
    define_method("test_#{m.to_s}_find_str") { assert EtcUtils.send(m, 'root').name.eql? "root"  }
  end

  def test_etc_utils_sgetspent
    assert sgetspent(find_spwd('root').to_s).name.eql? "root"
    assert sgetsgent(find_sgrp('root').to_s).name.eql? "root"
  end

  def test_etc_utils_fgetsgent_cp_tmp
    assert_nothing_raised do
      fh = File.open('/etc/gshadow', 'r')
      File.open('/tmp/_gshadow', File::RDWR|File::CREAT, 0600) { |tf|
        while ( g = fgetsgent(fh) )
          g.fputs(tf)
        end
      }
      fh.close
      assert FileUtils.compare_file('/etc/gshadow', '/tmp/_gshadow') == true
    end
  ensure
    FileUtils.remove_file('/tmp/_gshadow')
  end

  def test_etc_utils_fgetspent_cp_tmp
    assert_nothing_raised do
      fh = File.open('/etc/shadow', 'r')
      File.open('/tmp/_shadow', File::RDWR|File::CREAT, 0640) { |tf|
        while ( s = fgetspent(fh) )
          s.fputs(tf)
        end
      }
      fh.close
      assert FileUtils.compare_file('/etc/shadow', '/tmp/_shadow') == true
    end
  ensure
    FileUtils.remove_file('/tmp/_shadow');
  end

  def test_nsswitch_conf_gshadow
    assert_block "\n#{'*' * 75}
nsswitch.conf may be misconfigured. Consider adding the below to /etc/nsswitch.conf.
gshadow:\tfiles
See 'http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=699089' for more.\n" do
      getsgent
    end
  end

  def test_etc_utils_getspent
    assert_nothing_raised do
      setspent
      while ( f = getspent )
        # Make sure we get to the end and then don't bomb.
      end
    end
  end

end
