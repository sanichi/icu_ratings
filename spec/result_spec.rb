# encoding: utf-8
require File.dirname(__FILE__) + '/spec_helper'

module ICU
  describe RatedResult do
    context "a basic rated result" do
      before(:all) do
        @o = ICU::RatedPlayer.new(2)
      end
      
      it "needs a round, opponent and score (win, loss or draw)" do
        r = ICU::RatedResult.new(1, @o, 'W')
        r.round.should == 1
        r.opponent.should be_an_instance_of(ICU::RatedPlayer)
        r.score.should == 1.0
      end
    end

    context "restrictions, or lack thereof, on attributes" do
      before(:each) do
        @p = ICU::RatedPlayer.new(2)
      end
      
      it "round numbers must be positive" do
        lambda { ICU::RatedResult.new(0, 1, 'W') }.should raise_error(/invalid.*round number/i)
        lambda { ICU::RatedResult.new(-1, 1, 'W') }.should raise_error(/invalid.*round number/i)
      end

      it "the opponent must be an object, not a number" do
        lambda { ICU::RatedResult.new(1, 0,  'W') }.should raise_error(/invalid.*class.*Fixnum/)
        lambda { ICU::RatedResult.new(1, @p, 'W') }.should_not raise_error
      end

      it "the score can be any of the usual suspects" do
        ['W', 'w',  1,  1.0].each { |r| ICU::RatedResult.new(1, @p, r).score.should == 1.0 }
        ['L', 'l',  0,  0.0].each { |r| ICU::RatedResult.new(1, @p, r).score.should == 0.0 }
        ['D', 'd', '½', 0.5].each { |r| ICU::RatedResult.new(1, @p, r).score.should == 0.5 }
        lambda { ICU::RatedResult.new(1, @p, '') }.should raise_error(/invalid.*score/)
      end
    end

    context "#opponents_score" do
      before(:each) do
        @p = ICU::RatedPlayer.new(2)
      end
      
      it "should give the score from the opponent's perspective" do
        ICU::RatedResult.new(1, @p, 'W').opponents_score.should == 0.0
        ICU::RatedResult.new(1, @p, 'L').opponents_score.should == 1.0
        ICU::RatedResult.new(1, @p, 'D').opponents_score.should == 0.5
      end
    end

    context "equality" do
      before(:each) do
        @p1 = ICU::RatedPlayer.new(1)
        @p2 = ICU::RatedPlayer.new(2)
        @r1 = ICU::RatedResult.new(1, @p1, 'W')
        @r2 = ICU::RatedResult.new(1, @p1, 'W')
        @r3 = ICU::RatedResult.new(2, @p1, 'W')
        @r4 = ICU::RatedResult.new(1, @p2, 'W')
        @r5 = ICU::RatedResult.new(1, @p1, 'L')
      end

      it "should return true only if all attributes match" do
        (@r1 == @r2).should be_true
        (@r1 == @r3).should be_false
        (@r1 == @r4).should be_false
        (@r1 == @r5).should be_false
      end
    end
    
    context "Rdoc examples" do
      before(:each) do
        @t = ICU::RatedTournament.new
        @t.add_player(10)
        @t.add_player(20)
        @t.add_player(30)
        @t.add_result(1, 10, 20, 'W')
        [0,1,2,3,4].each { |num| @t.add_player(num) }
        [3,1].each { |rnd| @t.add_result(rnd, 0, rnd, 'W') }
        [4,2].each { |rnd| @t.add_result(rnd, 0, rnd, 'L') }
      end

      it "it is OK but unnecessary to add the same result from the other players perspective" do
        @t.player(10).results.size.should == 1
        @t.player(20).results.size.should == 1
        lambda { @t.add_result(1, 20, 10, 'L') }.should_not raise_error
        @t.player(10).results.size.should == 1
        @t.player(20).results.size.should == 1
      end
      
      it "adding results against other players in the same round will cause an exception" do
        lambda { @t.add_result(1, 10, 30, 'W') }.should raise_error(/inconsistent/i)
        lambda { @t.add_result(1, 10, 20, 'L') }.should raise_error(/inconsistent/i)
      end
      
      it "a player cannot have a result against himself/herself" do
        lambda { @t.add_result(2, 10, 10, 'D') }.should raise_error(/players.*cannot.*sel[fv]/i)
      end
      
      it "results are returned in score order irrespecive of the order they're added in" do
        @t.player(0).results.map{ |r| r.round }.join(',').should == "1,2,3,4"
      end
    end
  end
end