class RootEUTest < EtcUtilsTest
  SG_MAP[:sp] = { :file => SHADOW,  :ext => 'wd' }
  SG_MAP[:sg] = { :file => GSHADOW, :ext => 'rp' }

  def test_nsswitch_conf_gshadow
    assert_block "\n#{'*' * 75}
nsswitch.conf may be misconfigured. Consider adding the below to /etc/nsswitch.conf.
gshadow:\tfiles
See 'http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=699089' for more.\n" do
      setsgent
      !!getsgent
    end
  end

  def test_sget_secure_ent
    assert sgetspent(find_spwd('root').to_entry).name.eql? "root"
    assert sgetsgent(find_sgrp('root').to_entry).name.eql? "root"
  end
end
