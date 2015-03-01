require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

module ICU
  module Util
    describe Date do
      context "#parsedate!" do
        it "should return instances of class Date" do
          expect(Date.parsedate!('2001-01-01')).to be_a(::Date)
        end

        it "should parse standard dates" do
          expect(Date.parsedate!('2001-01-01').to_s).to eq('2001-01-01')
          expect(Date.parsedate!('1955-11-09').to_s).to eq('1955-11-09')
        end

        it "should handle US format" do
          expect(Date.parsedate!('03/30/2009').to_s).to eq('2009-03-30')
        end

        it "should handle European format" do
          expect(Date.parsedate!('30/03/2009').to_s).to eq('2009-03-30')
        end

        it "should prefer European format" do
          expect(Date.parsedate!('02/03/2009').to_s).to eq('2009-03-02')
        end

        it "should handle US style when there's no alternative" do
          expect(Date.parsedate!('02/23/2009').to_s).to eq('2009-02-23')
        end

        it "should handle single digits" do
          expect(Date.parsedate!('9/8/2006').to_s).to eq('2006-08-09')
        end

        it "should handle names of months" do
          expect(Date.parsedate!('9th Nov 1955').to_s).to eq('1955-11-09')
          expect(Date.parsedate!('16th June 1986').to_s).to eq('1986-06-16')
        end

        it "should raise exception on error" do
          expect { Date.parsedate!('2010-13-32') }.to raise_error(/invalid date/)
        end

        it "should accept Date objects as well as strings" do
          expect(Date.parsedate!(::Date.parse('2013-07-01'))).to eq(::Date.parse('2013-07-01'))
        end
      end

      context "#age" do
        it "should return age in years" do
          expect(Date.age('2001-01-01', '2001-01-01')).to eq(0.0)
          expect(Date.age('2001-01-01', '2002-01-01')).to eq(1.0)
          expect(Date.age('2001-01-01', '2001-01-02')).to be_within(0.01).of(1/365)
          expect(Date.age('2001-01-01', '2001-02-01')).to be_within(0.01).of(1/12.0)
          expect(Date.age('1955-11-09', '2010-01-17')).to be_within(0.01).of(54.2)
          expect(Date.age('2001-01-01', '2000-01-01')).to eq(-1.0)
        end

        it "should default second date to today" do
          expect(Date.age(::Date.today)).to eq(0.0)
        end
      end
    end
  end
end
