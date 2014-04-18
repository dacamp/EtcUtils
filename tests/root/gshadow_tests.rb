# This needs to be mentioned during install, but it's just going to
# fail a majority of the time until 14.04.
#
#   def test_nsswitch_conf_gshadow
#     assert_block "\n#{'*' * 75}
# nsswitch.conf may be misconfigured. Consider adding the below to /etc/nsswitch.conf.
# gshadow:\tfiles
# See 'http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=699089' for more.\n" do
#       setsgent
#       !!getsgent
#     end
#   end

class GShadowTest < RootEUTest

  def test_sgetsgent
    assert sgetsgent(find_sgrp('root').to_entry).name.eql? "root"
  end
end
