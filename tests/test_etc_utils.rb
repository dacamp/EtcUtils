require 'etcutils_test_helper'
require "#{$eu_user}/etc_utils"

class EtcUtilsTest < Test::Unit::TestCase
  SG_MAP = Hash.new.tap do |h|
    h[:pw] = { :file => PASSWD,  :ext => 'd'  }
    h[:gr] = { :file => GROUP,   :ext => 'p'  }
  end

  def test_constants
    assert_equal(EtcUtils, EU)
    assert_equal('1.0.0', EU::VERSION)

    # User DB Files
    [:passwd, :group, :shadow, :gshadow].each do |m|
      a = m.to_s.downcase
      if File.exist?(f = "/etc/#{a}")
        assert_equal(eval("EU::#{a.upcase}"), f)
        assert EU.send("has_#{a}?"), "EtcUtils.has_#{a}? should be true."
      end
    end

    assert_equal(EU::SHELL, '/bin/bash')
  end

  def test_reflective_methods
    assert_not_nil(EU.me, "EU.me should not be nil")
    assert_equal(EU.me.class, EtcUtils::Passwd, "EU.me should return EtcUtils::Passwd class")
    assert_equal(EU.me.uid, EU.getlogin.uid)
  end

  # This could fail if there are less than 5 entries in either /etc/group or /etc/passwd
  # This could also fail if the user cannot read from these files
  def test_pw_gr_star_ent
    assert_nothing_raised do
      EU.setXXent
    end

    assert_not_nil EU.getpwent, "Should be able to read from /etc/passwd"
    assert_not_nil EU.getgrent, "Should be able to read from /etc/group"
    3.times do
      EU.getpwent
      EU.getgrent
    end

    assert_not_equal(0, (EU.getpwent).uid, "EU.getpwent should iterate through /etc/passwd")
    assert_not_equal(0, (EU.getgrent).gid, "EU.getgrent should iterate through /etc/group")

    assert_nothing_raised do
      EU.setXXent
    end

    assert_equal(0, (EU.getpwent).uid, "EU.setXXent should reset all user DB files (/etc/passwd)")
    assert_equal(0, (EU.getgrent).gid, "EU.setXXent should reset all user DB files (/etc/group)")

    assert_nothing_raised do
      EU.endXXent
    end
  end

  def test_eu_find_pwd
    assert_block("EU.setpwent should reset /etc/passwd") do
      2.times do
        assert_nothing_raised { setpwent }
        assert_not_nil(u = find_pwd(0))
        assert_equal(0, u.uid, "EU.find_pwd(0) should only return User with ID zero")
        assert_nothing_raised { endpwent }
      end
    end
  end

  def test_to_entry
    r = find_pwd(0).to_entry
    assert_equal(r.chomp, r, "#to_entry should not have a trailing newline")
  end

  # Helper method to normalize group file lines (sort members alphabetically)
  # The gem sorts group members when writing, so we need to normalize for comparison
  def normalize_group_line(line)
    parts = line.chomp.split(':')
    return line.chomp if parts.length < 4
    # Sort the members (4th field) alphabetically
    parts[3] = parts[3].split(',').sort.join(',')
    parts.join(':')
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
          # For group files, normalize member order since gem sorts them alphabetically
          if xx == :gr
            orig_lines = File.readlines(SG_MAP[xx][:file]).map { |l| normalize_group_line(l) }
            new_lines = File.readlines(tmp_fn).map { |l| normalize_group_line(l) }
            assert_equal orig_lines, new_lines,
              "DIFF FAILED: #{SG_MAP[xx][:file]} <=> #{tmp_fn}\n" << `diff #{SG_MAP[xx][:file]} #{tmp_fn}`
          else
            assert FileUtils.compare_file(SG_MAP[xx][:file], tmp_fn) == true,
              "DIFF FAILED: #{SG_MAP[xx][:file]} <=> #{tmp_fn}\n" << `diff #{SG_MAP[xx][:file]} #{tmp_fn}`
          end
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
    define_method("test_#{m}_find_int") { assert_equal(EtcUtils.send(m, 0).name, "root", "EU.find_#{xx}#{SG_MAP[xx][:ent]}(0) should find root by ID")  }
    define_method("test_#{m}_find_str") { assert_equal(EtcUtils.send(m, 'root').name, "root", "EU.find_#{xx}#{SG_MAP[xx][:ent]}('root') should find root by name") }
  end
end
