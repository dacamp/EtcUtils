class RootEUTest < Test::Unit::TestCase
  # This all needs to be refactored anyways
  # Required to pass 1.8.7
  def test_true
    assert true
  end
end
require 'root/shadow_tests'
if EU.getsgent
  require 'root/gshadow_tests'
end
