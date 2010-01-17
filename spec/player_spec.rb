# encoding: utf-8
require File.dirname(__FILE__) + '/spec_helper'

module ICU
  describe RatedPlayer do
    context "#new - different types of players" do
      before(:all) do
        @r = ICU::RatedPlayer.new(1, :rating => 2000, :kfactor => 10.0)
        @p = ICU::RatedPlayer.new(2, :rating => 1500, :games => 10)
        @f = ICU::RatedPlayer.new(3, :rating => 2500)
        @u = ICU::RatedPlayer.new(4)
      end

      it "rated players have a rating and k-factor" do
        @r.num.should     == 1
        @r.rating.should  == 2000
        @r.kfactor.should == 10.0
        @r.games.should   be_nil
        @r.type.should    == :rated
        @r.full_rating?.should be_true
      end

      it "provisionally rated players have a rating and number of games" do
        @p.num.should     == 2
        @p.rating.should  == 1500
        @p.kfactor.should be_nil
        @p.games.should   == 10
        @p.type.should    == :provisional
        @p.full_rating?.should be_false
      end

      it "foreign players just have a rating" do
        @f.num.should     == 3
        @f.rating.should  == 2500
        @f.kfactor.should be_nil
        @f.games.should   be_nil
        @f.type.should    == :foreign
        @f.full_rating?.should be_true
      end

      it "unrated players just have nothing other than their number" do
        @u.num.should     == 4
        @u.rating.should  be_nil
        @u.kfactor.should be_nil
        @u.games.should   be_nil
        @u.type.should    == :unrated
        @u.full_rating?.should be_false
      end

      it "other combinations are invalid" do
        [
          { :games => 10 },
          { :games => 10, :kfactor => 10 },
          { :games => 10, :kfactor => 10, :rating  => 1000 },
          { :kfactor => 10 },
        ].each { |opts| lambda { ICU::RatedPlayer.new(1, opts) }.should raise_error(/invalid.*combination/i) }
      end
    end

    context "#new - miscellaneous" do
      it "attribute values can be given by strings, even when space padded" do
        p = ICU::RatedPlayer.new(' 1 ', :kfactor => ' 10.0 ', :rating => ' 1000 ')
        p.num.should     == 1
        p.kfactor.should == 10.0
        p.rating.should  == 1000
      end
    end

    context "restrictions, or lack thereof, on attributes" do
      it "the player number can be zero or even negative" do
        lambda { ICU::RatedPlayer.new(-1) }.should_not raise_error
        lambda { ICU::RatedPlayer.new(0)  }.should_not raise_error
      end

      it "k-factors must be positive" do
        lambda { ICU::RatedPlayer.new(1, :kfactor =>  0) }.should raise_error(/invalid.*factor/i)
        lambda { ICU::RatedPlayer.new(1, :kfactor => -1) }.should raise_error(/invalid.*factor/i)
      end

      it "the rating can be zero or even negative" do
        lambda { ICU::RatedPlayer.new(1, :rating =>  0) }.should_not raise_error
        lambda { ICU::RatedPlayer.new(1, :rating => -1) }.should_not raise_error
      end

      it "ratings are stored as floats but can be specified with an integer" do
        ICU::RatedPlayer.new(1, :rating => 1234.5).rating.should == 1234.5
        ICU::RatedPlayer.new(1, :rating => 1234.0).rating.should == 1234
        ICU::RatedPlayer.new(1, :rating =>   1234).rating.should == 1234
      end

      it "the number of games shoud not exceed 20" do
        lambda { ICU::RatedPlayer.new(1, :rating => 1000, :games => 19) }.should_not raise_error
        lambda { ICU::RatedPlayer.new(1, :rating => 1000, :games => 20) }.should raise_error
        lambda { ICU::RatedPlayer.new(1, :rating => 1000, :games => 21) }.should raise_error
      end

      it "a description, such as a name, but can be any object, is optional" do
        ICU::RatedPlayer.new(1, :desc => 'Fischer, Robert').desc.should == 'Fischer, Robert'
        ICU::RatedPlayer.new(1, :desc => 1).desc.should be_an_instance_of(Fixnum)
        ICU::RatedPlayer.new(1, :desc => 1.0).desc.should be_an_instance_of(Float)
        ICU::RatedPlayer.new(1).desc.should be_nil
      end
    end

    context "results" do
      before(:each) do
        @p  = ICU::RatedPlayer.new(1, :kfactor => 10, :rating => 1000)
        @r1 = ICU::RatedResult.new(1, ICU::RatedPlayer.new(2), 'W')
        @r2 = ICU::RatedResult.new(2, ICU::RatedPlayer.new(3), 'L')
        @r3 = ICU::RatedResult.new(3, ICU::RatedPlayer.new(4), 'D')
      end

      it "should be returned in round order" do
        @p.add_result(@r2)
        @p.results.size.should == 1
        @p.results[0].should == @r2
        @p.add_result(@r3)
        @p.results.size.should == 2
        @p.results[0].should == @r2
        @p.results[1].should == @r3
        @p.add_result(@r1)
        @p.results.size.should == 3
        @p.results[0].should == @r1
        @p.results[1].should == @r2
        @p.results[2].should == @r3
      end

      it "the total score should stay consistent with results as they are added" do
        @p.score.should == 0.0
        @p.add_result(@r1)
        @p.score.should == 1.0
        @p.add_result(@r2)
        @p.score.should == 1.0
        @p.add_result(@r3)
        @p.score.should == 1.5
      end
    end

    context "calculation of K-factor" do
      it "should return 16 for players 2100 and above" do
        ICU::RatedPlayer.kfactor(:rating => 2101, :start => '2010-07-10', :dob => '1955-11-09', :joined => '1974-01-01').should == 16
        ICU::RatedPlayer.kfactor(:rating => 2100, :start => '2010-07-10', :dob => '1955-11-09', :joined => '1974-01-01').should == 16
        ICU::RatedPlayer.kfactor(:rating => 2099, :start => '2010-07-10', :dob => '1955-11-09', :joined => '1974-01-01').should_not == 16
      end

      it "should otherwise return 40 for players aged under 21 at the start of the tournament" do
        ICU::RatedPlayer.kfactor(:rating => 2000, :start => '2010-07-10', :dob => '1989-07-11', :joined => '1999-01-01').should == 40
        ICU::RatedPlayer.kfactor(:rating => 2000, :start => '2010-07-10', :dob => '1989-07-10', :joined => '1999-01-01').should_not == 40
        ICU::RatedPlayer.kfactor(:rating => 2000, :start => '2010-07-10', :dob => '1989-07-09', :joined => '1999-01-01').should_not == 40
      end

      it "should otherwise return 32 for players with under 8 years experience at the start of the tournament" do
        ICU::RatedPlayer.kfactor(:rating => 2000, :start => '2010-07-10', :dob => '1989-01-01', :joined => '2002-07-11').should == 32
        ICU::RatedPlayer.kfactor(:rating => 2000, :start => '2010-07-10', :dob => '1989-01-01', :joined => '2002-07-10').should_not == 32
        ICU::RatedPlayer.kfactor(:rating => 2000, :start => '2010-07-10', :dob => '1989-01-01', :joined => '2002-07-09').should_not == 32
      end

      it "should otherwise return 24" do
        ICU::RatedPlayer.kfactor(:rating => 2000, :start => '2010-07-10', :dob => '1989-01-01', :joined => '2002-01-01').should == 24
      end
    end

    context "Rdoc examples" do
      before(:each) do
        @t = ICU::RatedTournament.new
        @t.add_player(1)
      end

      it "the same player number can't be added twice" do
        lambda { @t.add_player(2) }.should_not raise_error
        lambda { @t.add_player(2) }.should raise_error
      end

      it "parameters can be specified using strings, even with whitespace padding" do
        p = @t.add_player("  0  ", :rating => "  2000.5  ", :kfactor => "  20.5  ")
        p.num.should == 0
        p.num.should be_an_instance_of(Fixnum)
        p.rating.should == 2000.5
        p.rating.should be_an_instance_of(Float)
        p.kfactor.should == 20.5
        p.kfactor.should be_an_instance_of(Float)
        p = @t.add_player("  -1  ", :rating => "  2000.5  ", :games => "  15  ")
        p.games.should == 15
        p.games.should be_an_instance_of(Fixnum)
      end

      it "the games parameter should not exceed 20" do
        lambda { @t.add_player(2, :rating => 1500, :games => 20 ) }.should raise_error
      end

      it "adding different player types" do
        p = @t.add_player(3, :rating => 2000, :kfactor => 16)
        p.type.should == :rated
        p = @t.add_player(4, :rating => 1600, :games => 10)
        p.type.should == :provisional
        p = @t.add_player(5)
        p.type.should == :unrated
        p = @t.add_player(6, :rating => 2500)
        p.type.should == :foreign
        lambda { @t.add_player(7, :rating => 2000, :kfactor => 16, :games => 10) }.should raise_error
        lambda { t.add_plater(7, :kfactor => 16) }.should raise_error
      end
    end
  end
end