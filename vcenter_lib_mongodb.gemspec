# coding: utf-8

require File.expand_path('../lib/vcenter_lib_mongodb/version', __FILE__)

Gem::Specification.new do |spec|
  spec.name          = 'vcenter_lib_mongodb'
  spec.version       = VcenterLibMongodb::VERSION
  spec.authors       = ['Michael Meyling']
  spec.email         = ['search@meyling.com']
  spec.summary       = 'save and synchronize vcenter information in a mongodb'
  spec.description   = 'We will see what we can do.'
  spec.homepage      = 'https://github.com/m-31/vcenter_lib_mongodb'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'vcenter_lib'
  spec.add_dependency 'mongo'
  spec.add_dependency 'puppetdb_query'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'webmock'
  spec.add_development_dependency 'simplecov', '~> 0.9.0'
end
