require 'etcutils_test_helper'

class GroupClassTest < Test::Unit::TestCase
  def test_sgetgrent
    assert sgetgrent(find_grp('root').to_entry).name.eql? "root"
  end
end
