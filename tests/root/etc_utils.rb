# These will fail on OSx/BSD currently
require 'root/shadow_tests'

if EU.getsgent
  require 'root/gshadow_tests'
end
