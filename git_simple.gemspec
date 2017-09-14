# coding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'git_simple/version'

Gem::Specification.new do |spec|
  spec.name     = 'git_simple'
  spec.version  = GitSimple::VERSION
  spec.authors  = ['Andrew Sullivan Cant']
  spec.email    = ['mail@andrewsullivancant.ca']

  spec.summary  = 'Simple git commands in Ruby.'
  spec.homepage = 'http://github.com/acant/git_simple'
  spec.license  = 'MIT'

  spec.required_ruby_version = '>= 2.0.0'

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'rugged', '0.26.0'

  spec.add_development_dependency 'bundler',       '~> 1.15'
  spec.add_development_dependency 'rake',          '~> 10.0'
  spec.add_development_dependency 'rspec',         '~> 3.0'
  spec.add_development_dependency 'rspec-timecop', '~> 0.3'
  spec.add_development_dependency 'rspec-tabular', '~> 0.1'
  spec.add_development_dependency 'cucumber',      '~> 2.4.0'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'rubocop-rspec'
end
