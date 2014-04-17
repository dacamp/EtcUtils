class UserLockingTest < EULockingTest
  def test_locking
    assert_raise SystemCallError do
      EU.locked?
    end
  end
end
