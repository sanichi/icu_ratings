# :enddoc:

icu_ratings_files = Array.new
icu_ratings_files.concat %w{tournament player result}

icu_ratings_files.each { |file| require "icu_ratings/#{file}" }
