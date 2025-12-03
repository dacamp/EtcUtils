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

class GShadowTest < Test::Unit::TestCase

  ##
  # Module Specific Methods
  #

  def test_set_end_ent
    assert_nothing_raised do
      EU.setsgent
    end

    assert_nothing_raised do
      EU.endsgent
    end
  end

  def test_find
    assert_nil EtcUtils.find_sgrp("testuser"), "EU.find_sgrp should return nil if user does not exist"
    assert_equal("root", EtcUtils.find_sgrp("root").name, "EU.find_sgrp(str) should return user if it exists")
    assert_equal("root", EtcUtils.find_sgrp(0).name, "EU.find_sgrp(int) should return user if it exists")
    assert_nothing_raised do
      EU.setsgent
    end
    assert_equal(getsgnam('root').name, getsgent.name, "EU.getsgnam('root') and EU.getsgent should return the same user")
  end

  def test_shadow_vs_passwd
    assert_equal(find_sgrp('root').name, find_grp('root').name, "EU.find_sgrp and EU.find_grp should return the same user")
  end

  def test_sgetsgent
    assert sgetsgent(find_sgrp('root').to_entry).name.eql? "root"
  end

  def test_getsgent_while
    assert_nothing_raised do
      EtcUtils.setsgent
      while ( ent = EtcUtils.getsgent ); nil; end
    end
  end

  # Helper method to normalize gshadow file lines (sort members/admins alphabetically)
  # The gem sorts group members when writing, so we need to normalize for comparison
  def normalize_gshadow_line(line)
    parts = line.chomp.split(':')
    return line.chomp if parts.length < 4
    # Sort the admins (3rd field) and members (4th field) alphabetically
    parts[2] = parts[2].split(',').sort.join(',') if parts[2]
    parts[3] = parts[3].split(',').sort.join(',') if parts[3]
    parts.join(':')
  end

  def test_fgetsgent_and_putsgent
    tmp_fn = "/tmp/_fgetsgent_test"
    assert_nothing_raised do
      fh = File.open('/etc/gshadow', 'r')
      File.open(tmp_fn, File::RDWR|File::CREAT, 0600) { |tmp_fh|
        while ( ent = EtcUtils.fgetsgent(fh) )
          EU.putsgent(ent, tmp_fh)
        end
      }
      fh.close
    end
    assert File.exist?(tmp_fn), "EU.fgetsgent(fh) should write to fh"
    # Compare files with normalized member order (gem sorts members alphabetically)
    orig_lines = File.readlines("/etc/gshadow").map { |l| normalize_gshadow_line(l) }
    new_lines = File.readlines(tmp_fn).map { |l| normalize_gshadow_line(l) }
    assert_equal orig_lines, new_lines,
      "DIFF FAILED: /etc/gshadow <=> #{tmp_fn}\n" << `diff /etc/gshadow #{tmp_fn}`
  ensure
    FileUtils.remove_file(tmp_fn);
  end

  def test_putsgent_raises
    FileUtils.touch "/tmp/_gshadow"

    assert_raise IOError do
      f = File.open("/tmp/_gshadow", 'r')
      u = EU.find_sgrp('root')
      u.fputs f
    end
  ensure
    FileUtils.remove_file("/tmp/_gshadow");
  end

  ##
  # EU::GShadow class methods
  #
  def test_class_set_end_ent
    assert_nothing_raised do
      EU::GShadow.set
    end

    assert_nothing_raised do
      EU::GShadow.end
    end
  end

  def test_class_get
    assert_not_nil EU::GShadow.get
  end

  def test_class_each
    assert_nothing_raised do
      EU::GShadow.each do |e|
        assert e.name
      end
    end
  end

  def test_class_find
    assert_equal "root", EU::GShadow.find('root').name
  end

  def test_class_parse
    assert_nothing_raised do
      EtcUtils::GShadow.parse("root:x:0:")
    end
  end

  def test_class_parse_members
    assert_nothing_raised do
      assert_equal Array, EtcUtils::GShadow.parse("root:*::").members.class
    end

    assert_equal "user", EtcUtils::GShadow.parse("root:*:admin:user").members.first
  end

  def test_class_parse_admins
    assert_nothing_raised do
      assert_equal Array, EtcUtils::GShadow.parse("root:*::").admins.class
    end

    assert_equal "admin", EtcUtils::GShadow.parse("root:*:admin:user").admins.first
  end

  ##
  # EU::GShadow instance methods
  #
  def test_init
    assert_equal EU::GShadow, EU::GShadow.new.class
  end

  def test_instance_methods
    e = EU::GShadow.find('root')
    assert_equal 'root', e.name
    assert_not_nil e.passwd
    assert_equal 'root', EU::GShadow.parse(e.to_entry).name
    assert_equal String, e.to_entry.class
    assert_equal Array, e.members.class
    assert_equal Array, e.admins.class
    assert e.respond_to?(:fputs)
  end
end
