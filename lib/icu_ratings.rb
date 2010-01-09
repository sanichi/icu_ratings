# :enddoc:

icu_ratings_files = Array.new
icu_ratings_files.concat %w{tournament player result}

dir = File.dirname(__FILE__)

icu_ratings_files.each { |file| require "#{dir}/icu_ratings/#{file}" }
