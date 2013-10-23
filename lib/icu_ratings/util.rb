require 'date' # needed for 1.9.1

module ICU
  module Util
    module Date

      # Parses strings into date objects, interpreting nn/nn/nnnn as dd/mm/yyyy. It raises an exception on error.
      #
      #   parsedate!('1955-11-09')       # => Date (1955-11-09)
      #   parsedate!('02/03/2009')       # => Date (2009-03-02)
      #   parsedate!('02/23/2009')       # => Date (2009-02-23)
      #   parsedate!('16th June 1986')   # => Date (1986-06-16)
      #   parsedate!('not a date')       # exception raised
      #
      # Note that the parse method of the Date class behaves differently in Ruby 1.8.7 and 1.9.1.
      # In 1.8.7 it assumes American dates and will raise ArgumentError on "30/03/2003".
      # In 1.9.1 it assumes European dates and will raise ArgumentError on "03/30/2003".
      #
      def self.parsedate!(date)
        return date.clone if date.is_a?(::Date)
        string = date.to_s.strip
        raise "invalid date (#{date})" unless string.match(/[1-9]/)
        string = [$3].concat($2.to_i > 12 ? [$1, $2] : [$2, $1]).join('-') if string.match(/^(\d{1,2}).(\d{1,2}).(\d{4})$/)
        begin
          ::Date.parse(string, true)
        rescue
          raise "invalid date (#{date})"
        end
      end

      # Returns the difference of two dates:
      #
      #   age(born, date)  # age in years at the given date (Float)
      #   age(born)        # age in years now (today)
      #
      # Internally it uses _parsedate!_ so can throw a exception if an invalid date is supplied.
      def self.age(born, date=::Date.today)
        born = parsedate!(born)
        date = parsedate!(date)
        date.year - born.year + (date.yday - born.yday) / 366.0
      end
    end
  end
end
