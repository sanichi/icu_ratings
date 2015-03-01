# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

module ICU
  describe RatedResult do
    context "a basic rated result" do
      before(:all) do
        @o = ICU::RatedPlayer.factory(2)
      end

      it "needs a round, opponent and score (win, loss or draw)" do
        r = ICU::RatedResult.new(1, @o, 'W')
        expect(r.round).to eq(1)
        expect(r.opponent).to be_a_kind_of(ICU::RatedPlayer)
        expect(r.score).to eq(1.0)
      end
    end

    context "restrictions, or lack thereof, on attributes" do
      before(:each) do
        @p = ICU::RatedPlayer.factory(2)
      end

      it "round numbers must be positive" do
        expect { ICU::RatedResult.new(0, 1, 'W') }.to raise_error(/invalid.*round number/i)
        expect { ICU::RatedResult.new(-1, 1, 'W') }.to raise_error(/invalid.*round number/i)
      end

      it "the opponent must be an object, not a number" do
        expect { ICU::RatedResult.new(1, 0,  'W') }.to raise_error(/invalid.*class.*Fixnum/)
        expect { ICU::RatedResult.new(1, @p, 'W') }.not_to raise_error
      end

      it "the score can be any of the usual suspects" do
        ['W', 'w',  1,  1.0].each { |r| expect(ICU::RatedResult.new(1, @p, r).score).to eq(1.0) }
        ['L', 'l',  0,  0.0].each { |r| expect(ICU::RatedResult.new(1, @p, r).score).to eq(0.0) }
        ['D', 'd', '½', 0.5].each { |r| expect(ICU::RatedResult.new(1, @p, r).score).to eq(0.5) }
        expect { ICU::RatedResult.new(1, @p, '') }.to raise_error(/invalid.*score/)
      end
    end

    context "#opponents_score" do
      before(:each) do
        @p = ICU::RatedPlayer.factory(2)
      end

      it "should give the score from the opponent's perspective" do
        expect(ICU::RatedResult.new(1, @p, 'W').opponents_score).to eq(0.0)
        expect(ICU::RatedResult.new(1, @p, 'L').opponents_score).to eq(1.0)
        expect(ICU::RatedResult.new(1, @p, 'D').opponents_score).to eq(0.5)
      end
    end

    context "equality" do
      before(:each) do
        @p1 = ICU::RatedPlayer.factory(1)
        @p2 = ICU::RatedPlayer.factory(2)
        @r1 = ICU::RatedResult.new(1, @p1, 'W')
        @r2 = ICU::RatedResult.new(1, @p1, 'W')
        @r3 = ICU::RatedResult.new(2, @p1, 'W')
        @r4 = ICU::RatedResult.new(1, @p2, 'W')
        @r5 = ICU::RatedResult.new(1, @p1, 'L')
      end

      it "should return true only if all attributes match" do
        expect(@r1 == @r2).to be_truthy
        expect(@r1 == @r3).to be_falsey
        expect(@r1 == @r4).to be_falsey
        expect(@r1 == @r5).to be_falsey
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
        expect(@t.player(10).results.size).to eq(1)
        expect(@t.player(20).results.size).to eq(1)
        expect { @t.add_result(1, 20, 10, 'L') }.not_to raise_error
        expect(@t.player(10).results.size).to eq(1)
        expect(@t.player(20).results.size).to eq(1)
      end

      it "adding results against other players in the same round will cause an exception" do
        expect { @t.add_result(1, 10, 30, 'W') }.to raise_error(/inconsistent/i)
        expect { @t.add_result(1, 10, 20, 'L') }.to raise_error(/inconsistent/i)
      end

      it "a player cannot have a result against himself/herself" do
        expect { @t.add_result(2, 10, 10, 'D') }.to raise_error(/players.*cannot.*sel[fv]/i)
      end

      it "results are returned in score order irrespecive of the order they're added in" do
        expect(@t.player(0).results.map{ |r| r.round }.join(',')).to eq("1,2,3,4")
      end
    end
  end
end