$:.unshift File.dirname(__FILE__) + "/../lib"

require 'test/unit'
require 'etcutils'

class Test::Unit::TestCase; include EtcUtils; end
