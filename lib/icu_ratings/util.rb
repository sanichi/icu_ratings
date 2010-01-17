require 'date' # needed for 1.9.1

module ICU
  class Util

=begin rdoc

== Parsing dates

Parse strings into date objects, interpreting nn/nn/nnnn as dd/mm/yyyy. Raises exception on error.

  Util.parsedate!('1955-11-09')       # => Date (1955-11-09)
  Util.parsedate!('02/03/2009')       # => Date (2009-03-02)
  Util.parsedate!('02/23/2009')       # => Date (2009-02-23)
  Util.parsedate!('16th June 1986')   # => Date (1986-06-16)
  Util.parsedate!('not a date')       # exception raised

Note that the parse method of the Date class behaves differently in Ruby 1.8.7 and 1.9.1.
In 1.8.7 it assumes American dates and will raise ArgumentError on "30/03/2003".
In 1.9.1 it assumes European dates and will raise ArgumentError on "03/30/2003".

=end

    def self.parsedate!(date)
      string = date.to_s.strip
      raise "invalid date (#{date})" unless string.match(/[1-9]/)
      string = [$3].concat($2.to_i > 12 ? [$1, $2] : [$2, $1]).join('-') if string.match(/^(\d{1,2}).(\d{1,2}).(\d{4})$/)
      begin
        Date.parse(string, true)
      rescue
        raise "invalid date (#{date})"
      end
    end
  end
end