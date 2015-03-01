# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
require 'icu_ratings/version'

Gem::Specification.new do |s|
  s.name = %q{icu_ratings}

  s.authors = ["Mark Orr"]
  s.email = %q{mark.j.l.orr@googlemail.com}
  s.description = %q{Build an object that represents a chess tournament then get it to calculate ratings of all the players.}
  s.homepage = %q{http://github.com/sanichi/icu_ratings}
  s.summary = %q{For rating chess tournaments.}
  s.version = ICU::Ratings::VERSION
  s.rubyforge_project = "icu_ratings"
  s.license = "MIT"

  s.extra_rdoc_files = %w(LICENCE README.rdoc)
  s.files = Dir.glob("lib/**/*.rb") + Dir.glob("spec/*.rb") + %w(LICENCE README.rdoc)
  s.require_paths = ["lib"]
  s.test_files = Dir.glob("spec/*.rb")
  
  s.add_development_dependency("bundler", "~> 1.8")
  s.add_development_dependency("rake", "~> 10.4")
  s.add_development_dependency("rspec", "~> 3.2")
  s.add_development_dependency("rdoc", "~> 4.2")
end

