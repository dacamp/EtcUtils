$:.unshift File.dirname(__FILE__) + "/../lib"

require 'test/unit'
require 'etcutils'

$eu_user = EtcUtils.me.uid.zero? ? "root" : "user"

class Test::Unit::TestCase; include EtcUtils; end
