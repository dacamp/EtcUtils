# coding: utf-8

Gem::Specification.new do |spec|
  spec.platform      = Gem::Platform::CURRENT
  spec.name          = "etcutils"
  spec.version       = "0.1.0"
  spec.author        = "David Campbell"
  spec.email         = "dcampbell@nestlabs.com"
  spec.description   = "Ruby Extension that allows for reads and writes to the /etc user db."
  spec.summary       = %q{This gem is specific to *nix environments.  It's a rewrite of libshadow-ruby allowing for reads and writes to passwd,shadow,group, and gshadow /etc files.  There are probably still bugs, so use at your own risk.}
  spec.homepage      = "https://github.com/dacamp/etcutils"

  spec.require_paths = '.'
  spec.files         = `git ls-files`.split($/)
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})

  spec.extensions = ['ext/extconf.rb']

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
