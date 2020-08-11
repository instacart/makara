# -*- encoding: utf-8 -*-
require File.expand_path('../lib/makara/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Mike Nelson"]
  gem.email         = ["mike@mikeonrails.com"]
  gem.description   = %q{Read-write split your DB yo}
  gem.summary       = %q{Read-write split your DB yo}
  gem.homepage      = "https://github.com/taskrabbit/makara"
  gem.licenses      = ['MIT']
  gem.metadata      = {
                        "source_code_uri" => 'https://github.com/taskrabbit/makara'
                      }

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "makara"
  gem.require_paths = ["lib"]
  gem.version       = Makara::VERSION

  gem.add_dependency 'activerecord', '>= 3.0.0'
end
