# coding: utf-8
$:.push File.expand_path("../lib", __FILE__)
require 'etcutils/version'

Gem::Specification.new do |spec|
  spec.name          = "etcutils"
  spec.version       = EtcUtils::VERSION
  spec.platform      = Gem::Platform::RUBY
  spec.authors       = ["David Campbell"]
  spec.email         = "david@mrcampbell.org"
  spec.description   = "Ruby Extension that allows for reads and writes to the /etc user db."
  spec.summary       = %q{This gem is specific to *nix environments, allowing for reads and writes to passwd,shadow,group, and gshadow /etc files.  It is inspired by Std-lib Etc and the Gem libshadow-ruby however modified to use classes rather than structs to allow for future growth.  There are probably still bugs, so use at your own risk.}
  spec.homepage      = "https://github.com/dacamp/etcutils"
  spec.licenses      = ["MIT"]

  spec.extensions    = ['ext/etcutils/extconf.rb']
  spec.files         = `git ls-files`.split($/)
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_path  = ["lib"]

  spec.has_rdoc      = false

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rake-compiler"
end
