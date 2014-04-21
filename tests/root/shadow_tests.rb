# 
# getspent
# find_spwd
# setspent
# endspent
# sgetspent
# getspnam
#
# fgetspent
# putspent

class ShadowTest < Test::Unit::TestCase

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
    assert_equal("root", EtcUtils.find_spwd("root").name, "EU.find_spwd should return user if it exists")
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
end
