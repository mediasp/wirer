# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'wirer/version'

spec = Gem::Specification.new do |s|
  s.name   = "wirer"
  s.version = Wirer::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ['Matthew Willson', 'Tom Chipchase']
  s.email = ["matthew@playlouder.com", "tom.chipchase@gmail.com"]
  s.summary = "A lightweight dependency injection framework to help wire up objects in Ruby"

  s.add_development_dependency('rake')
  s.add_development_dependency('minitest', '>2.1')
  s.add_development_dependency('mocha', '>0.11')
  s.add_development_dependency('yard')
  s.add_development_dependency('redcarpet')

  s.files = Dir.glob("{lib}/**/*") + ['README.rb']
end
