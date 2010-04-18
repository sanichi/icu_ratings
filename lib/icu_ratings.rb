# :enddoc:
dir = File.dirname(__FILE__)
$:.unshift(dir) unless $:.include?(dir) || $:.include?(File.expand_path(dir))
%w{tournament player result util}.each { |f| require "icu_ratings/#{f}" }
