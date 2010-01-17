# :enddoc:
dir = File.dirname(__FILE__)
%w{tournament player result util}.each { |f| require "#{dir}/icu_ratings/#{f}" }
