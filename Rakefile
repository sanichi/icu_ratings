require 'rubygems'
require 'rake'
require 'rake/rdoctask'
require 'spec/rake/spectask'
require File.expand_path(File.dirname(__FILE__) + '/lib/icu_ratings/version')

version = ICU::Ratings::VERSION

task :default => :spec

desc "Build a new gem for version #{version}"
task :build do
  system "gem build icu_ratings.gemspec"
  system "mv {,pkg/}icu_ratings-#{version}.gem"
end

desc "Release version #{version} of the gem to rubygems.org"
task :release => :build do
  system "gem push pkg/icu_ratings-#{version}.gem"
end

desc "Create a tag for version #{version}"
task :tag do
  system "git tag v#{version} -m 'Tagging version #{version}'"
end

desc "Push the master branch to github"
task :push do
  system "git push origin master"
end

Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/**/*_spec.rb']
  spec.spec_opts  = ['--colour --format nested']
end

Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.title    = "ICU Ratings #{version}"
  rdoc.rdoc_dir = 'rdoc'
  rdoc.options  = ["--charset=utf-8"]
  rdoc.rdoc_files.include('lib/**/*.rb', 'README.rdoc', 'LICENCE')
end
