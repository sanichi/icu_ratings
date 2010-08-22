require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

module ICU
  describe Util do
    context "#parsedate!" do
      it "should return instances of class Date" do
        Util.parsedate!('2001-01-01').should be_a(Date)
      end

      it "should parse standard dates" do
        Util.parsedate!('2001-01-01').to_s.should == '2001-01-01'
        Util.parsedate!('1955-11-09').to_s.should == '1955-11-09'
      end

      it "should handle US format" do
        Util.parsedate!('03/30/2009').to_s.should == '2009-03-30'
      end

      it "should handle European format" do
        Util.parsedate!('30/03/2009').to_s.should == '2009-03-30'
      end

      it "should prefer European format" do
        Util.parsedate!('02/03/2009').to_s.should == '2009-03-02'
      end

      it "should handle US style when there's no alternative" do
        Util.parsedate!('02/23/2009').to_s.should == '2009-02-23'
      end

      it "should handle single digits" do
        Util.parsedate!('9/8/2006').to_s.should == '2006-08-09'
      end

      it "should handle names of months" do
        Util.parsedate!('9th Nov 1955').to_s.should == '1955-11-09'
        Util.parsedate!('16th June 1986').to_s.should == '1986-06-16'
      end

      it "should raise exception on error" do
        lambda { Util.parsedate!('2010-13-32') }.should raise_error(/invalid date/)
      end

      it "should accept Date objects as well as strings" do
        Util.parsedate!(Date.parse('2013-07-01')).should == Date.parse('2013-07-01')
      end
    end

    context "#age" do
      it "should return age in years" do
        Util.age('2001-01-01', '2001-01-01').should == 0.0
        Util.age('2001-01-01', '2002-01-01').should == 1.0
        Util.age('2001-01-01', '2001-01-02').should be_close(1/365.0, 0.01)
        Util.age('2001-01-01', '2001-02-01').should be_close(1/12.0, 0.01)
        Util.age('1955-11-09', '2010-01-17').should be_close(54.2, 0.01)
        Util.age('2001-01-01', '2000-01-01').should == -1.0
      end

      it "should default second date to today" do
        Util.age(Date.today).should == 0.0
      end
    end
  end
end
