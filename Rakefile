require 'rake'
require 'rdoc/task'
require 'rspec/core/rake_task'
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

RSpec::Core::RakeTask.new do |t|
  t.rspec_opts  = ['--colour --format doc']
end

RDoc::Task.new do |rdoc|
  rdoc.title = "ICU Ratings #{version}"
  rdoc.main  = "README.rdoc"
  rdoc.rdoc_files.include("README.rdoc", "lib/**/*.rb")
end
