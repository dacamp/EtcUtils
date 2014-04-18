require 'etcutils_test_helper'

class PasswdClassTest < Test::Unit::TestCase
  def test_sgetpwent
    assert sgetpwent(find_pwd('root').to_entry).name.eql? "root"
  end
end
