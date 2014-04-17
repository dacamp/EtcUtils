$:.unshift File.dirname(__FILE__) + "/../lib"

require 'test/unit'
require 'etcutils'

$root = EU.me.uid.zero?

class Test::Unit::TestCase; include EtcUtils; end
