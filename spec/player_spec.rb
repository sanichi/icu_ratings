# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

module ICU
  describe RatedPlayer do
    context "#factory - different types of players" do
      before(:all) do
        @r = ICU::RatedPlayer.factory(1, :rating => 2000, :kfactor => 10.0)
        @p = ICU::RatedPlayer.factory(2, :rating => 1500, :games => 10)
        @f = ICU::RatedPlayer.factory(3, :rating => 2500)
        @u = ICU::RatedPlayer.factory(4)
      end

      it "rated players have a rating and k-factor" do
        expect(@r.num).to     eq(1)
        expect(@r.rating).to  eq(2000)
        expect(@r.kfactor).to eq(10.0)
        expect(@r.type).to    eq(:rated)
        expect(@r).not_to respond_to(:games)
      end

      it "provisionally rated players have a rating and number of games" do
        expect(@p.num).to    eq(2)
        expect(@p.rating).to eq(1500)
        expect(@p.games).to  eq(10)
        expect(@p.type).to   eq(:provisional)
        expect(@p).not_to respond_to(:kfactor)
      end

      it "foreign players just have a rating" do
        expect(@f.num).to    eq(3)
        expect(@f.rating).to eq(2500)
        expect(@f.type).to   eq(:foreign)
        expect(@f).not_to respond_to(:kfactor)
        expect(@f).not_to respond_to(:games)
      end

      it "unrated players just have nothing other than their number" do
        expect(@u.num).to  eq(4)
        expect(@u.type).to eq(:unrated)
        expect(@u).not_to respond_to(:rating)
        expect(@u).not_to respond_to(:kfactor)
        expect(@u).not_to respond_to(:games)
      end

      it "other combinations are invalid" do
        [
          { :games => 10 },
          { :games => 10, :kfactor => 10 },
          { :games => 10, :kfactor => 10, :rating  => 1000 },
          { :kfactor => 10 },
        ].each { |opts| expect { ICU::RatedPlayer.factory(1, opts) }.to raise_error(/invalid.*combination/i) }
      end
    end

    context "#new - miscellaneous" do
      it "attribute values can be given by strings, even when space padded" do
        p = ICU::RatedPlayer.factory(' 1 ', :kfactor => ' 10.0 ', :rating => ' 1000 ')
        expect(p.num).to     eq(1)
        expect(p.kfactor).to eq(10.0)
        expect(p.rating).to  eq(1000)
      end
    end

    context "restrictions, or lack thereof, on attributes" do
      it "the player number can be zero or even negative" do
        expect { ICU::RatedPlayer.factory(-1) }.not_to raise_error
        expect { ICU::RatedPlayer.factory(0)  }.not_to raise_error
      end

      it "k-factors must be positive" do
        expect { ICU::RatedPlayer.factory(1, :kfactor =>  0) }.to raise_error(/invalid.*factor/i)
        expect { ICU::RatedPlayer.factory(1, :kfactor => -1) }.to raise_error(/invalid.*factor/i)
      end

      it "the rating can be zero or even negative" do
        expect { ICU::RatedPlayer.factory(1, :rating =>  0) }.not_to raise_error
        expect { ICU::RatedPlayer.factory(1, :rating => -1) }.not_to raise_error
      end

      it "ratings are stored as floats but can be specified with an integer" do
        expect(ICU::RatedPlayer.factory(1, :rating => 1234.5).rating).to eq(1234.5)
        expect(ICU::RatedPlayer.factory(1, :rating => 1234.0).rating).to eq(1234)
        expect(ICU::RatedPlayer.factory(1, :rating =>   1234).rating).to eq(1234)
      end

      it "the number of games shoud not exceed 20" do
        expect { ICU::RatedPlayer.factory(1, :rating => 1000, :games => 19) }.not_to raise_error
        expect { ICU::RatedPlayer.factory(1, :rating => 1000, :games => 20) }.to raise_error
        expect { ICU::RatedPlayer.factory(1, :rating => 1000, :games => 21) }.to raise_error
      end

      it "a description, such as a name, but can be any object, is optional" do
        expect(ICU::RatedPlayer.factory(1, :desc => 'Fischer, Robert').desc).to eq('Fischer, Robert')
        expect(ICU::RatedPlayer.factory(1, :desc => 1).desc).to be_an_instance_of(Fixnum)
        expect(ICU::RatedPlayer.factory(1, :desc => 1.0).desc).to be_an_instance_of(Float)
        expect(ICU::RatedPlayer.factory(1).desc).to be_nil
      end
    end

    context "results" do
      before(:each) do
        @p  = ICU::RatedPlayer.new(1, :kfactor => 10, :rating => 1000)
        @r1 = ICU::RatedResult.new(1, ICU::RatedPlayer.factory(2), 'W')
        @r2 = ICU::RatedResult.new(2, ICU::RatedPlayer.factory(3), 'L')
        @r3 = ICU::RatedResult.new(3, ICU::RatedPlayer.factory(4), 'D')
      end

      it "should be returned in round order" do
        @p.add_result(@r2)
        expect(@p.results.size).to eq(1)
        expect(@p.results[0]).to eq(@r2)
        @p.add_result(@r3)
        expect(@p.results.size).to eq(2)
        expect(@p.results[0]).to eq(@r2)
        expect(@p.results[1]).to eq(@r3)
        @p.add_result(@r1)
        expect(@p.results.size).to eq(3)
        expect(@p.results[0]).to eq(@r1)
        expect(@p.results[1]).to eq(@r2)
        expect(@p.results[2]).to eq(@r3)
      end

      it "the total score should stay consistent with results as they are added" do
        expect(@p.score).to eq(0.0)
        @p.add_result(@r1)
        expect(@p.score).to eq(1.0)
        @p.add_result(@r2)
        expect(@p.score).to eq(1.0)
        @p.add_result(@r3)
        expect(@p.score).to eq(1.5)
      end
    end

    context "calculation of K-factor" do
      it "should return 16 for players 2100 and above" do
        expect(ICU::RatedPlayer.kfactor(:rating => 2101, :start => '2010-07-10', :dob => '1955-11-09', :joined => '1974-01-01')).to eq(16)
        expect(ICU::RatedPlayer.kfactor(:rating => 2100, :start => '2010-07-10', :dob => '1955-11-09', :joined => '1974-01-01')).to eq(16)
        expect(ICU::RatedPlayer.kfactor(:rating => 2099, :start => '2010-07-10', :dob => '1955-11-09', :joined => '1974-01-01')).not_to eq(16)
      end

      it "should otherwise return 40 for players aged under 21 at the start of the tournament" do
        expect(ICU::RatedPlayer.kfactor(:rating => 2000, :start => '2010-07-10', :dob => '1989-07-11', :joined => '1999-01-01')).to eq(40)
        expect(ICU::RatedPlayer.kfactor(:rating => 2000, :start => '2010-07-10', :dob => '1989-07-10', :joined => '1999-01-01')).not_to eq(40)
        expect(ICU::RatedPlayer.kfactor(:rating => 2000, :start => '2010-07-10', :dob => '1989-07-09', :joined => '1999-01-01')).not_to eq(40)
      end

      it "should otherwise return 32 for players with under 8 years experience at the start of the tournament" do
        expect(ICU::RatedPlayer.kfactor(:rating => 2000, :start => '2010-07-10', :dob => '1989-01-01', :joined => '2002-07-11')).to eq(32)
        expect(ICU::RatedPlayer.kfactor(:rating => 2000, :start => '2010-07-10', :dob => '1989-01-01', :joined => '2002-07-10')).not_to eq(32)
        expect(ICU::RatedPlayer.kfactor(:rating => 2000, :start => '2010-07-10', :dob => '1989-01-01', :joined => '2002-07-09')).not_to eq(32)
      end

      it "should otherwise return 24" do
        expect(ICU::RatedPlayer.kfactor(:rating => 2000, :start => '2010-07-10', :dob => '1989-01-01', :joined => '2002-01-01')).to eq(24)
      end
      
      it "should throw an exception if required information is missing" do
        expect { ICU::RatedPlayer.kfactor(:start => '2010-07-10', :dob => '1989-01-01', :joined => '2002-01-01') }.to raise_error(/missing.*rating/)
        expect { ICU::RatedPlayer.kfactor(:rating => 2000, :dob => '1989-01-01', :joined => '2002-01-01') }.to raise_error(/missing.*start/)
        expect { ICU::RatedPlayer.kfactor(:rating => 2000, :start => '2010-07-10', :joined => '2002-01-01') }.to raise_error(/missing.*dob/)
        expect { ICU::RatedPlayer.kfactor(:rating => 2000, :start => '2010-07-10', :dob => '1989-01-01') }.to raise_error(/missing.*join/)
      end
    end

    context "Rdoc examples" do
      before(:each) do
        @t = ICU::RatedTournament.new
        @t.add_player(1)
      end

      it "the same player number can't be added twice" do
        expect { @t.add_player(2) }.not_to raise_error
        expect { @t.add_player(2) }.to raise_error
      end

      it "parameters can be specified using strings, even with whitespace padding" do
        p = @t.add_player("  0  ", :rating => "  2000.5  ", :kfactor => "  20.5  ")
        expect(p.num).to eq(0)
        expect(p.num).to be_an_instance_of(Fixnum)
        expect(p.rating).to eq(2000.5)
        expect(p.rating).to be_an_instance_of(Float)
        expect(p.kfactor).to eq(20.5)
        expect(p.kfactor).to be_an_instance_of(Float)
        p = @t.add_player("  -1  ", :rating => "  2000.5  ", :games => "  15  ")
        expect(p.games).to eq(15)
        expect(p.games).to be_an_instance_of(Fixnum)
      end

      it "the games parameter should not exceed 20" do
        expect { @t.add_player(2, :rating => 1500, :games => 20 ) }.to raise_error
      end

      it "adding different player types" do
        p = @t.add_player(3, :rating => 2000, :kfactor => 16)
        expect(p.type).to eq(:rated)
        p = @t.add_player(4, :rating => 1600, :games => 10)
        expect(p.type).to eq(:provisional)
        p = @t.add_player(5)
        expect(p.type).to eq(:unrated)
        p = @t.add_player(6, :rating => 2500)
        expect(p.type).to eq(:foreign)
        expect { @t.add_player(7, :rating => 2000, :kfactor => 16, :games => 10) }.to raise_error
        expect { t.add_plater(7, :kfactor => 16) }.to raise_error
      end
    end
  end
end