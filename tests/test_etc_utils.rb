require 'etcutils_test_helper'

class EtcUtilsTest < Test::Unit::TestCase

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
        #
      end
      !locked?
    end
  end

  def test_etc_utils_sgetspent
    assert sgetspent("root:!::0:::::").name.eql? "root"
  end

  def test_etc_utils_getspnam_args
    assert_raise TypeError do
      getspnam(1)
    end
  end

  def test_etc_utils_fgetsgent_cp_tmp
    assert_nothing_raised do
      fh = File.open('/etc/gshadow', 'r')
      File.open('/tmp/_gshadow', File::RDWR|File::CREAT, 0640) { |tf|
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
