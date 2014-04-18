class RootEUTest < Test::Unit::TestCase; end
require 'root/shadow_tests'
if EU.getsgent.nil?
  require 'root/gshadow_tests'
end
