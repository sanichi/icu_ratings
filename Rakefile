require 'rubygems'
require 'rake'
require 'rake/rdoctask'
require 'spec/rake/spectask'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name             = "icu_ratings"
    gem.summary          = "For rating chess tournaments."
    gem.description      = "Build an object that represents a chess tournament then get it to calculate ratings of all the players."
    gem.homepage         = "http://github.com/sanichi/icu_ratings"
    gem.authors          = ["Mark Orr"]
    gem.email            = "mark.j.l.orr@googlemail.com"
    gem.files            = FileList['{lib,spec}/**/*', 'README.rdoc', 'LICENCE', 'VERSION.yml', '.gitignore', '.autotest']
    gem.has_rdoc         = true
    gem.extra_rdoc_files = ['README.rdoc', 'LICENCE'],
    gem.rdoc_options     = ["--charset=utf-8"]
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install jeweler."
end

task :default => :spec

Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/**/*_spec.rb']
  spec.spec_opts  = ['--colour --format nested']
end

Rake::RDocTask.new(:rdoc) do |rdoc|
  if File.exist?('VERSION.yml')
    config  = YAML.load(File.read('VERSION.yml'))
    version = "#{config[:major]}.#{config[:minor]}.#{config[:patch]}"
  else
    version = ""
  end

  rdoc.title    = "ICU Ratings #{version}"
  rdoc.rdoc_dir = 'rdoc'
  rdoc.options  = ["--charset=utf-8"]
  rdoc.rdoc_files.include('lib/**/*.rb', 'README.rdoc', 'LICENCE')
end
