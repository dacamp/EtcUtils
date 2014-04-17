class RootLockingTest < EULockingTest
  def test_locking
    assert_equal(lock, locked?)
    assert_not_equal(unlock, locked?)
  end

  def test_locking_block
    assert_block "Couldn't run a block inside of lock()" do
      lock { assert locked? }
      !locked?
    end
  end

  def test_locked_after_exception
    assert_block "Files remained locked when an exception is raised inside of lock()" do
      begin
        lock { raise "foobar" }
      rescue
        !locked?
      end
    end
  end
end
