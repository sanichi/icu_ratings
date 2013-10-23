require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

module ICU
  module Util
    describe Date do
      context "#parsedate!" do
        it "should return instances of class Date" do
          Date.parsedate!('2001-01-01').should be_a(::Date)
        end

        it "should parse standard dates" do
          Date.parsedate!('2001-01-01').to_s.should == '2001-01-01'
          Date.parsedate!('1955-11-09').to_s.should == '1955-11-09'
        end

        it "should handle US format" do
          Date.parsedate!('03/30/2009').to_s.should == '2009-03-30'
        end

        it "should handle European format" do
          Date.parsedate!('30/03/2009').to_s.should == '2009-03-30'
        end

        it "should prefer European format" do
          Date.parsedate!('02/03/2009').to_s.should == '2009-03-02'
        end

        it "should handle US style when there's no alternative" do
          Date.parsedate!('02/23/2009').to_s.should == '2009-02-23'
        end

        it "should handle single digits" do
          Date.parsedate!('9/8/2006').to_s.should == '2006-08-09'
        end

        it "should handle names of months" do
          Date.parsedate!('9th Nov 1955').to_s.should == '1955-11-09'
          Date.parsedate!('16th June 1986').to_s.should == '1986-06-16'
        end

        it "should raise exception on error" do
          lambda { Date.parsedate!('2010-13-32') }.should raise_error(/invalid date/)
        end

        it "should accept Date objects as well as strings" do
          Date.parsedate!(::Date.parse('2013-07-01')).should == ::Date.parse('2013-07-01')
        end
      end

      context "#age" do
        it "should return age in years" do
          Date.age('2001-01-01', '2001-01-01').should == 0.0
          Date.age('2001-01-01', '2002-01-01').should == 1.0
          Date.age('2001-01-01', '2001-01-02').should be_within(0.01).of(1/365)
          Date.age('2001-01-01', '2001-02-01').should be_within(0.01).of(1/12.0)
          Date.age('1955-11-09', '2010-01-17').should be_within(0.01).of(54.2)
          Date.age('2001-01-01', '2000-01-01').should == -1.0
        end

        it "should default second date to today" do
          Date.age(::Date.today).should == 0.0
        end
      end
    end
  end
end
