require 'etcutils_test_helper'

class EULockingTest < Test::Unit::TestCase
  if $root
    require 'root/locking'
  else
    require 'user/locking'
  end
end
