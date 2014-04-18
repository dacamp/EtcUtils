class ShadowTest < RootEUTest

  def test_sgetspent
    assert EU.sgetspent(EU.find_spwd('root').to_entry).name.eql? "root"
  end
end
