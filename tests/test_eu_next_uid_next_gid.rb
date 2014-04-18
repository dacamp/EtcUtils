require 'etcutils_test_helper'

class EtcUtilsNextIDTest < Test::Unit::TestCase
  [:uid, :gid].each do |m|
    define_method("test_next_#{m}"){
      assert(EU.send("next_#{m}"), "EU.next_#{m} should return next available #{m.to_s.upcase}")
      assert_not_equal(EU.send("next_#{m}"), EU.send("next_#{m}"), "EU.next_#{m} should never return the same #{m.to_s.upcase}")
    }

    # #next_{u,g}id=x should always return x even if {U,G}ID x is assigned
    # Weird #send bug where EU.send("next_uid=",0) != EU.next_uid=0
    define_method("test_next_#{m}_equals"){
      assert_equal(0, eval("EU.next_#{m}=0"), "EU.next_#{m}=x should return x")
    }

    define_method("test_next_#{m}_params"){
      assert_not_equal(0, EU.send("next_#{m}", 0), "EU.next_#{m}(x) should return next available #{m.to_s.upcase} if x is unavailable")
      assert_equal(9999, EU.send("next_#{m}", 9999), "EU.next_#{m}(x) should return #{m.to_s.upcase} if x is available")
    }

    define_method("test_next_#{m}_raises"){
      assert_raise ArgumentError do
        EU.send("next_#{m}", 65534)
      end
      assert_raise ArgumentError do
        EU.send("next_#{m}=", -1)
      end
    }
  end
end
