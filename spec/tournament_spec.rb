# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

module ICU
  describe RatedTournament do
    context "restrictions, or lack thereof, on attributes" do
      it "a tournament can have an optional description, such as a name, but any object is allowed" do
        ICU::RatedTournament.new(:desc => 'Irish Championship 2010').desc.should == 'Irish Championship 2010'
        ICU::RatedTournament.new(:desc => 1.0).desc.should be_an_instance_of(Float)
        ICU::RatedTournament.new.desc.should be_nil
      end

      it "a tournament can have an optional start date" do
        ICU::RatedTournament.new(:start => '2010-01-01').start.should be_a(Date)
        ICU::RatedTournament.new(:start => '03/06/2013').start.to_s.should == '2013-06-03'
        ICU::RatedTournament.new(:start => Date.parse('1955-11-09')).start.to_s.should == '1955-11-09'
        ICU::RatedTournament.new.start.should be_nil
        lambda { ICU::RatedTournament.new(:start => 'error') }.should raise_error
      end

      it "should have setters for the optional arguments" do
        t = ICU::RatedTournament.new
        t.desc=("Championship")
        t.start=("2010-07-01")
        t.desc.should == "Championship"
        t.start.should == Date.parse("2010-07-01")
      end
    end

    context "#add_player and calculation of K-factor" do
      before(:each) do
        @t = ICU::RatedTournament.new(:start => "2010-07-10")
      end

      it "should set a K-factor of 16 for players with rating >= 2100" do
        @p = @t.add_player(1, :rating => 2200, :kfactor => { :dob => "1955-11-09", :joined => "1976-09-01" })
        @p.kfactor.should == 16
      end

      it "should set a K-factor of 40 for players with rating < 2100 and age < 21" do
        @p = @t.add_player(1, :rating => 2000, :kfactor => { :dob => "1995-01-10", :joined => "2009-09-01" })
        @p.kfactor.should == 40
      end

      it "should set a K-factor of 32 for players with rating < 2100, age >= 21 and experience < 8" do
        @p = @t.add_player(1, :rating => 2000, :kfactor => { :dob => "1975-01-10", :joined => "2005-09-01" })
        @p.kfactor.should == 32
      end

      it "should set a K-factor of 24 for players with rating < 2100, age >= 21 and experience >= 8" do
        @p = @t.add_player(1, :rating => 2000, :kfactor => { :dob => "1975-01-10", :joined => "1995-09-01" })
        @p.kfactor.should == 24
      end
    end

    context "#players and #player" do
      before(:each) do
        @t = ICU::RatedTournament.new
        @t.add_player(2)
        @t.add_player(1)
      end

      it "should return the players in number-order" do
        @t.players.size.should == 2
        @t.players[0].num.should == 1
        @t.players[1].num.should == 2
      end

      it "should return the player object with the matching number" do
        @t.player(1).num.should == 1
        @t.player(2).num.should == 2
        @t.player(3).should be_nil
      end
    end

    context "#add_result" do
      before(:each) do
        @t  = ICU::RatedTournament.new
        @p1 = @t.add_player(1)
        @p2 = @t.add_player(2)
        @p3 = @t.add_player(3)
      end

      it "should be added to both players" do
        @t.add_result(1, @p1, @p2, 'L')
        @p1.results.size.should == 1
        @p1.results[0].should == ICU::RatedResult.new(1, @p2, 'L')
        @p2.results.size.should == 1
        @p2.results[0].should == ICU::RatedResult.new(1, @p1, 'W')
        @p3.results.size.should == 0
        @t.add_result(2, @p3, @p2, 'W')
        @p1.results.size.should == 1
        @p2.results.size.should == 2
        @p2.results[0].should == ICU::RatedResult.new(1, @p1, 'W')
        @p2.results[1].should == ICU::RatedResult.new(2, @p3, 'L')
        @p3.results.size.should == 1
        @p3.results[0].should == ICU::RatedResult.new(2, @p2, 'W')
      end

      it "player objects or numbers can be used" do
        lambda { @t.add_result(1, @p1, @p2, 'L') }.should_not raise_error
        lambda { @t.add_result(2, 1, 2, 'W') }.should_not raise_error
      end

      it "the player numbers should exist already in the tournament" do
        lambda { @t.add_result(2, 1, 4, 'W') }.should raise_error(/player number.*4/)
        lambda { @t.add_result(2, 5, 2, 'W') }.should raise_error(/player number.*5/)
      end

      it "adding precisely the same result more than once is okay and changes nothing" do
        @t.add_result(1, @p1, @p2, 'L')
        @t.add_result(1, @p1, @p2, 'L')
        @t.add_result(1, @p2, @p1, 'W')
        @p1.results.size.should == 1
        @p2.results.size.should == 1
      end

      it "a player cannot have two different results in the same round" do
        @t.add_result(1, @p1, @p2, 'L')
        lambda { @t.add_result(1, @p1, @p2, 'W') }.should raise_error(/inconsistent/)
        lambda { @t.add_result(1, @p1, @p3, 'W') }.should raise_error(/inconsistent/)
        lambda { @t.add_result(1, @p3, @p2, 'W') }.should raise_error(/inconsistent/)
      end

      it "players cannot have results against themselves" do
        lambda { @t.add_result(1, @p1, @p1, 'W') }.should raise_error(/against.*themsel(f|ves)/)
      end
    end

    context "#rate - corner case - tournament is empy" do
      it "should not throw an exception" do
        @t = ICU::RatedTournament.new
        lambda { @t.rate! }.should_not raise_error
      end
    end

    context "#rate - all players rated, artificial example" do
      before(:each) do
        @t = ICU::RatedTournament.new
        (1..4).each do |num|
          @t.add_player(num, :kfactor => 10 * num, :rating => 2200 - 100 * (num - 1))
        end
        @t.add_result(1, 1, 2, 'W')
        @t.add_result(1, 3, 4, 'W')
        @t.add_result(2, 1, 3, 'W')
        @t.add_result(2, 2, 4, 'W')
        @t.add_result(3, 1, 4, 'W')
        @t.add_result(3, 2, 3, 'W')
      end

      it "before the tournament is rated" do
        (1..4).each do |num|
          p = @t.player(num)
          p.expected_score.should == 0.0
          p.rating_change.should == 0.0
          p.new_rating.should == p.rating
        end
      end

      it "after the tournament is rated" do
        @t.rate!

        @t.player(1).expected_score.should be_within(0.001).of(2.249)
        @t.player(2).expected_score.should be_within(0.001).of(1.760)
        @t.player(3).expected_score.should be_within(0.001).of(1.240)
        @t.player(4).expected_score.should be_within(0.001).of(0.751)

        @t.player(1).rating_change.should be_within(0.01).of(7.51)
        @t.player(2).rating_change.should be_within(0.01).of(4.81)
        @t.player(3).rating_change.should be_within(0.01).of(-7.21)
        @t.player(4).rating_change.should be_within(0.01).of(-30.05)

        @t.player(1).new_rating.should be_within(0.1).of(2207.5)
        @t.player(2).new_rating.should be_within(0.1).of(2104.8)
        @t.player(3).new_rating.should be_within(0.1).of(1992.8)
        @t.player(4).new_rating.should be_within(0.1).of(1870.0)
      end
    end

    context "#rate - all players rated, real swiss example" do
      # 1   Killane, Jack     740     4             2:D   3:W   4:W   5:D   6:W
      # 2   Cassidy, Paul     194     4       1:D         3:D   4:W   5:W   6:W
      # 3   King, Melvyn      10214   3.5     1:L   2:D         4:W   5:W   6:W
      # 4   Dempsey, Denis    322     1.5     1:L   2:L   3:L         5:D   6:W
      # 5   Thomson, Andrew   1613    1       1:D   2:L   3:L   4:D         6:L
      # 6   Coveney, Maurice  255     1       1:L   2:L   3:L   4:L   5:W
      # see also http://en.wikipedia.org/wiki/Round-robin_tournament#Scheduling_algorithm
      before(:each) do
        @t = ICU::RatedTournament.new(:desc => 'Irish Veterans 2008')

        @t.add_player(1, :kfactor => 24, :rating => 1852, :desc => 'Jack Killane (740)')
        @t.add_player(2, :kfactor => 24, :rating => 1845, :desc => 'Paul Cassidy (194)')
        @t.add_player(3, :kfactor => 32, :rating => 1632, :desc => 'Melvin King (10214)')
        @t.add_player(4, :kfactor => 24, :rating => 1337, :desc => 'Dennis Dempsey (322)')
        @t.add_player(5, :kfactor => 24, :rating => 1493, :desc => 'Andrew Thomson (1613)')
        @t.add_player(6, :kfactor => 24, :rating => 1297, :desc => 'Maurice J. Coveney (255)')

        @t.add_result(1, 1, 2, 'D')
        @t.add_result(2, 1, 3, 'W')
        @t.add_result(3, 1, 4, 'W')
        @t.add_result(4, 1, 5, 'D')
        @t.add_result(5, 1, 6, 'W')

        @t.add_result(4, 2, 3, 'D')
        @t.add_result(2, 2, 4, 'W')
        @t.add_result(5, 2, 5, 'W')
        @t.add_result(3, 2, 6, 'W')

        @t.add_result(5, 3, 4, 'W')
        @t.add_result(3, 3, 5, 'W')
        @t.add_result(1, 3, 6, 'W')

        @t.add_result(1, 4, 5, 'D')
        @t.add_result(4, 4, 6, 'W')

        @t.add_result(2, 5, 6, 'L')

        @t.rate!
      end

      it "should get same results as ICU rating database" do
        [
          [1,  4.089, 1850],
          [2,  4.055, 1844],
          [3,  2.855, 1653],
          [4,  1.101, 1347],
          [5,  2.005, 1469],
          [6,  0.894, 1300],
        ].each do |item|
          num, expected_score, new_rating = item
          p = @t.player(num)
          p.expected_score.should be_within(0.001).of(expected_score)
          p.new_rating.should be_within(0.5).of(new_rating)
        end
      end

      it "tournament performances are not the same as ICU year-to-date performances" do
        [
          [1, 1867, 1761],
          [2, 1803, 1762],
          [3, 1650, 1725],
          [4, 1338, 1464],
          [5, 1358, 1353],
          [6, 1289, 1392],
        ].each do |item|
          num, ytd_performance, tournament_performance = item
          p = @t.player(num)
          p.performance.should_not be_within(0.5).of(ytd_performance)
          p.performance.should be_within(0.5).of(tournament_performance)
        end
      end
    end

    context "#rate - all players rated, real match example" do
      before(:each) do
        @t = ICU::RatedTournament.new(:desc => "Dempsey-O'Raghallaigh Match 2009")
        @t.add_player(1, :kfactor => 24, :rating => 1347, :desc => 'Dennis Dempsey (322)')
        @t.add_player(2, :kfactor => 32, :rating => 1303, :desc => "Paul O'Raghallaigh (10219)")
        @t.add_result(1, 1, 2, 'W')
        @t.add_result(2, 1, 2, 'W')
        @t.add_result(3, 1, 2, 'W')
        @t.rate!
      end

      it "should get same results as ICU rating database" do
        @t.player(1).expected_score.should be_within(0.001).of(1.689)
        @t.player(2).expected_score.should be_within(0.001).of(1.311)
        @t.player(1).new_rating.should be_within(0.5).of(1378)
        @t.player(2).new_rating.should be_within(0.5).of(1261)
      end
    end

    context "#rate - typical foreign tournament" do
      # Player,456,Fox,Anthony
      # 1,0,B,Berg,Antonin,1877,,CZE
      # 2,0,W,Zanikov,Konstantin,1972,,CZE
      # 3,=,B,Pozzi,Claudio,1931,,ITA
      # 4,=,W,Horak,Karel,2105,,CZE
      # 5,=,B,Chromovsky,Hynek,1808,,CZE
      # 6,1,W,Hulin,Petr,1975,,CZE
      # 7,=,B,Jancarik,Joel,1990,,CZE
      # 8,1,W,Andersen,Carsten,1982,,DEN
      # 9,=,B,Gooding,Ian,2107,,ENG
      #
      # Player,159,Cafolla,Peter
      # 1,0,W,Dolezal,Radoslav,2423,IM,CZE
      # 2,1,B,Pozzi,Claudio,1931,,ITA
      # 3,0,W,Srirhanzl,Radek,1621,,CZE
      # 4,1,B,Milfort,Vaclav,1779,,CZE
      # 5,0,W,Srba,Milan,2209,,CZE
      # 6,1,B,Hajek,Jaroslav,1967,,CZE
      # 7,=,B,Soucek,Milan,2151,,CZE
      # 8,=,W,Babar,Michael,2145,FM,GER
      # 9,0,B,Bartos,Jan,2227,FM,CZE
      before(:all) do
        @t = ICU::RatedTournament.new(:desc => 'Prague Open 2008')

        @t.add_player(1,  :rating => 2105, :kfactor => 16, :desc => 'Fox, Anthony (456)')
        @t.add_player(2,  :rating => 1976, :kfactor => 24, :desc => 'Cafolla, Peter (159)')
        @t.add_player(3,  :rating => 1877, :desc => 'Berg, Antonin')
        @t.add_player(4,  :rating => 1972, :desc => 'Zanikov, Konstantin')
        @t.add_player(5,  :rating => 1931, :desc => 'Pozzi, Claudio')
        @t.add_player(6,  :rating => 2105, :desc => 'Horak, Karel')
        @t.add_player(7,  :rating => 1808, :desc => 'Chromovsky, Hynek')
        @t.add_player(8,  :rating => 1975, :desc => 'Hulin, Petr')
        @t.add_player(9,  :rating => 1990, :desc => 'Jancarik, Joel')
        @t.add_player(10, :rating => 1982, :desc => 'Andersen, Carsten')
        @t.add_player(11, :rating => 2107, :desc => 'Gooding, Ian')
        @t.add_player(12, :rating => 2423, :desc => 'Dolezal, Radoslav')
        @t.add_player(14, :rating => 1621, :desc => 'Srirhanzl, Radek')
        @t.add_player(15, :rating => 1779, :desc => 'Milfort, Vaclav')
        @t.add_player(16, :rating => 2209, :desc => 'Srba, Milan')
        @t.add_player(17, :rating => 1967, :desc => 'Hajek, Jaroslav')
        @t.add_player(18, :rating => 2151, :desc => 'Soucek, Milan')
        @t.add_player(19, :rating => 2187, :desc => 'Babar, Michael')
        @t.add_player(20, :rating => 2227, :desc => 'Bartos, Jan')

        @t.add_result(1, 1, 3,  'L')
        @t.add_result(2, 1, 4,  'L')
        @t.add_result(3, 1, 5,  'D')
        @t.add_result(4, 1, 6,  'D')
        @t.add_result(5, 1, 7,  'D')
        @t.add_result(6, 1, 8,  'W')
        @t.add_result(7, 1, 9,  'D')
        @t.add_result(8, 1, 10, 'W')
        @t.add_result(9, 1, 11, 'D')

        @t.add_result(1, 2, 12, 'L')
        @t.add_result(2, 2, 5,  'W')
        @t.add_result(3, 2, 14, 'L')
        @t.add_result(4, 2, 15, 'W')
        @t.add_result(5, 2, 16, 'L')
        @t.add_result(6, 2, 17, 'W')
        @t.add_result(7, 2, 18, 'D')
        @t.add_result(8, 2, 19, 'D')
        @t.add_result(9, 2, 20, 'L')

        @t.rate!
      end

      it "foreign players should have no rating change but non-zero expected scores" do
        (3..20).each do |num|
          unless num == 13
            p = @t.player(num)
            p.expected_score.should_not == 0.0
            p.should_not respond_to(:rating_change)
            p.new_rating.should == p.rating
          end
        end
      end

      it "foreign players should have tournament performnce ratings" do
        [
          [3,  2505.0],
          [4,  2505.0],
          [5,  1840.5],
          [6,  2105.0],
          [7,  2105.0],
          [8,  1705.0],
          [9,  2105.0],
          [10, 1705.0],
          [11, 2105.0],
          [12, 2376.0],
          [14, 2376.0],
          [15, 1576.0],
          [16, 2376.0],
          [17, 1576.0],
          [18, 1976.0],
          [19, 1976.0],
          [20, 2376.0],
        ].each do |item|
          num, performance = item
          p = @t.player(num)
          p.performance.should == performance
        end
      end

      it "should get the same results as the ICU database for the Irish players" do
        af = @t.player(1)
        pc = @t.player(2)

        af.score.should == 4.5
        af.expected_score.should be_within(0.001).of(6.054)
        af.new_rating.should be_within(0.5).of(2080)

        pc.score.should == 4.0
        pc.expected_score.should be_within(0.001).of(3.685)
        pc.new_rating.should be_within(0.5).of(1984)
      end
    end

    context "#rate - a tournament with some provisionally rated players and some players without results" do
      before(:all) do
        @t = ICU::RatedTournament.new(:desc => "Malahide CC's 2007")
        @t.add_player(1,  :rating => 1751, :kfactor => 32, :desc => 'DALY, JUSTIN')
        @t.add_player(2,  :rating => 1716, :kfactor => 32, :desc => 'REILLY, PAUL')
        @t.add_player(3,  :rating => 1583, :kfactor => 24, :desc => "O'SULLIVAN, TOM")
        @t.add_player(4,  :rating => 1659, :kfactor => 24, :desc => 'McGRANE, KEVIN')
        @t.add_player(5,  :rating => 1647, :kfactor => 24, :desc => 'BISSETT, VINCENT')
        @t.add_player(6,  :rating => 1442, :kfactor => 24, :desc => 'ROCHE, CORMAC')
        @t.add_player(7,  :rating => 1665, :kfactor => 24, :desc => 'BUCKLEY, GERARD')
        @t.add_player(8,  :rating => 1601, :kfactor => 24, :desc => 'WHALLEY, ANTHONY')
        @t.add_player(9,  :rating => 1283, :kfactor => 24, :desc => 'SCOTT, SHAY')
        @t.add_player(10, :rating => 1469, :kfactor => 24, :desc => "O'CONGHAILE, DIARMUID")
        @t.add_player(11, :rating => 1376, :kfactor => 24, :desc => 'SHEARAN, JOHN')
        @t.add_player(12, :rating => 1096, :games   => 11, :desc => 'MOLDT, TOBIAS')
        @t.add_player(13, :rating => 1317, :kfactor => 24, :desc => 'MARTIN, SEAMUS')
        @t.add_player(14, :rating => 1613, :kfactor => 24, :desc => 'FREDJ, NIZAR')
        @t.add_player(15, :rating => 1554, :kfactor => 24, :desc => 'REID, BRIAN')
        @t.add_player(16, :rating => 1016, :games   => 7,  :desc => 'DONNELLY, VINCENT')

        # 1   DALY, JUSTIN           4.5   10:W  14:W   5:D   7:D   2:W   4:D
        @t.add_result(1, 1, 10, 'W')
        @t.add_result(2, 1, 14, 'W')
        @t.add_result(3, 1, 5,  'D')
        @t.add_result(4, 1, 7,  'D')
        @t.add_result(5, 1, 2,  'W')
        @t.add_result(6, 1, 4,  'D')

        # 2   REILLY, PAUL           4.5   13:W   7:D   3:W   5:W   1:L   8:W
        @t.add_result(1, 2, 13, 'W')
        @t.add_result(2, 2, 7,  'D')
        @t.add_result(3, 2, 3,  'W')
        @t.add_result(4, 2, 5,  'W')
        @t.add_result(5, 2, 1,  'L')
        @t.add_result(6, 2, 8,  'W')

        # 3   O'SULLIVAN, TOM        4     16:+   4:-   2:L   9:W  12:W   5:W
        @t.add_result(3, 3, 2,  'L')
        @t.add_result(4, 3, 9,  'W')
        @t.add_result(5, 3, 12, 'W')
        @t.add_result(6, 3, 5,  'W')

        # 4   McGRANE, KEVIN         4     11:W   3:-   7:D  12:W   8:W   1:D
        @t.add_result(1, 4, 11, 'W')
        @t.add_result(3, 4, 7,  'D')
        @t.add_result(4, 4, 12, 'W')
        @t.add_result(5, 4, 8,  'W')
        @t.add_result(6, 4, 1,  'D')

        # 5   BISSETT, VINCENT       3.5   17:+   8:W   1:D   2:L   7:W   3:L
        @t.add_result(2, 5, 8,  'W')
        @t.add_result(3, 5, 1,  'D')
        @t.add_result(4, 5, 2,  'L')
        @t.add_result(5, 5, 7,  'W')
        @t.add_result(6, 5, 3,  'L')

        # 6   ROCHE, CORMAC          3.5    7:L  13:W   8:L  10:W   9:D  12:W
        @t.add_result(1, 6, 7,  'L')
        @t.add_result(2, 6, 13, 'W')
        @t.add_result(3, 6, 8,  'L')
        @t.add_result(4, 6, 10, 'W')
        @t.add_result(5, 6, 9,  'D')
        @t.add_result(6, 6, 12, 'W')

        # 7   BUCKLEY, GERARD        3      6:W   2:D   4:D   1:D   5:L  11:D
        @t.add_result(1, 7, 6,  'W')
        @t.add_result(2, 7, 2,  'D')
        @t.add_result(3, 7, 4,  'D')
        @t.add_result(4, 7, 1,  'D')
        @t.add_result(5, 7, 5,  'L')
        @t.add_result(6, 7, 11, 'D')

        # 8   WHALLEY, ANTHONY       3     12:W   5:L   6:W  14:+   4:L   2:L
        @t.add_result(1, 8, 12, 'W')
        @t.add_result(2, 8, 5,  'L')
        @t.add_result(3, 8, 6,  'W')
        @t.add_result(5, 8, 4,  'L')
        @t.add_result(6, 8, 2,  'L')

        # 9   SCOTT, SHAY            3     14:L  11:D  13:W   3:L   6:D   0:W
        @t.add_result(1, 9, 14,  'L')
        @t.add_result(2, 9, 11,  'D')
        @t.add_result(3, 9, 13,  'W')
        @t.add_result(4, 9, 3,   'L')
        @t.add_result(5, 9, 6,   'D')

        # 10  O'CONGHAILE, DIARMUID  2.5    1:L  16:W  14:-   6:L  11:D  13:W
        @t.add_result(1, 10, 1,  'L')
        @t.add_result(2, 10, 16, 'W')
        @t.add_result(4, 10, 6,  'L')
        @t.add_result(5, 10, 11, 'D')
        @t.add_result(6, 10, 13, 'W')

        # 11  SHEARAN, JOHN          2.5    4:L   9:D  12:L  13:W  10:D   7:D
        @t.add_result(1, 11, 4,  'L')
        @t.add_result(2, 11, 9,  'D')
        @t.add_result(3, 11, 12, 'L')
        @t.add_result(4, 11, 13, 'W')
        @t.add_result(5, 11, 10, 'D')
        @t.add_result(6, 11, 7,  'D')

        # 12  MOLDT, TOBIAS          2      8:L  17:+  11:W   4:L   3:L   6:L
        @t.add_result(1, 12, 8,  'L')
        @t.add_result(3, 12, 11, 'W')
        @t.add_result(4, 12, 4,  'L')
        @t.add_result(5, 12, 3,  'L')
        @t.add_result(6, 12, 6,  'L')

        # 13  MARTIN, SEAMUS         1      2:L   6:L   9:L  11:L   0:W  10:L
        @t.add_result(1, 13, 2,  'L')
        @t.add_result(2, 13, 6,  'L')
        @t.add_result(3, 13, 9,  'L')
        @t.add_result(4, 13, 11, 'L')
        @t.add_result(6, 13, 10, 'L')

        # 14  FREDJ, NIZAR           1      9:W   1:L  10:-   8:-   0:    0:
        @t.add_result(1, 14, 9,  'W')
        @t.add_result(2, 14, 1,  'L')

        # 15  REID, BRIAN            .5     0:D   0:    0:    0:    0:    0:

        # 16  DONNELLY, VINCENT      0      3:-  10:L   0:    0:    0:    0:
        @t.add_result(2, 16, 10, 'L')

        @t.rate!
      end

      it "should agree with ICU database for rated players with results" do
        [
          [1,  3.97, 1768],
          [2,  3.87, 1736],
          [3,  2.50, 1595],
          [4,  3.23, 1678],
          [5,  2.39, 1650],
          [6,  3.19, 1449],
          [7,  3.46, 1654],
          [8,  2.83, 1581],
          [9,  1.39, 1298],
          [10, 2.97, 1458],
          [11, 2.69, 1372],
          [13, 1.68, 1277],
          [14, 1.18, 1609],
        ].each do |item|
          num, expected_score, new_rating = item
          p = @t.player(num)
          p.expected_score.should be_within(0.01).of(expected_score)
          p.new_rating.should be_within(0.5).of(new_rating)
          p.results.inject(p.rating){ |t,r| t + r.rating_change }.should be_within(0.5).of(new_rating)
        end
      end

      it "should agree with ICU database for provisionally rated players with results" do
        [
          [12,  0.59, 1157],
          [16,  0.07, 1023],
        ].each do |item|
          num, expected_score, new_rating = item
          p = @t.player(num)
          p.expected_score.should be_within(0.01).of(expected_score)
          p.new_rating.should be_within(0.5).of(new_rating)
        end
      end

      it "players who didn't play any rated games should not change their rating" do
        p = @t.player(15)
        p.expected_score.should == 0
        p.new_rating.should == p.rating
      end
    end

    context "#rate - a made-up tournament with players of all kinds" do
      #   1   Orr, Mark               1350    3      8:W   3:W   2:W
      #   2   Coughlan, Anne          251     2      7:W   4:W   1:L
      #   3   Kennedy, Cian           6607    2      6:W   1:L   4:W
      #   4   Ledwidge O'Brien, Aoife 10744   1      5:W   2:L   3:L
      #   5   Martin, Ryan            6988    2      4:L   7:W   6:W
      #   6   Hanley, Gerard          5701    1      3:L   8:W   5:L
      #   7   Fagan, Joseph           5502    1      2:L   5:L   8:W
      #   8   Hassett, James          10185   0      1:L   6:L   7:L
      # Used in an experiment to prove the rating database is insensitive to K-factors for performance ratings.
      # See the files in the SVN repository ICU/data/etc/experiments/test.txt.
      before(:all) do
        @t = ICU::RatedTournament.new(:desc => "K Factor Test")
        @t.add_player(1, :desc => 'Orr, Mark',               :rating => 2174, :kfactor => 16)  # rated
        @t.add_player(2, :desc => 'Coughlan, Anne',          :rating => 1167, :kfactor => 24)  # rated
        @t.add_player(3, :desc => 'Kennedy, Cian',           :rating =>  751, :games   => 19)  # provisional, almost rated
        @t.add_player(4, :desc => "Ledwidge O'Brien, Aoife", :rating => 1273, :games   => 19)  # provisional, almost rated
        @t.add_player(5, :desc => 'Martin, Ryan',            :rating =>  627, :games   => 10)  # provisional
        @t.add_player(6, :desc => 'Hanley, Gerard',          :rating =>  684, :games   => 10)  # provisional
        @t.add_player(7, :desc => 'Fagan, Joseph')                                             # unrated
        @t.add_player(8, :desc => 'Hassett, James')                                            # unrated
        @t.add_result(1, 1, 8, 'W')
        @t.add_result(1, 2, 7, 'W')
        @t.add_result(1, 3, 6, 'W')
        @t.add_result(1, 4, 5, 'W')
        @t.add_result(2, 1, 3, 'W')
        @t.add_result(2, 2, 4, 'W')
        @t.add_result(2, 5, 7, 'W')
        @t.add_result(2, 6, 8, 'W')
        @t.add_result(3, 1, 2, 'W')
        @t.add_result(3, 3, 4, 'W')
        @t.add_result(3, 5, 6, 'W')
        @t.add_result(3, 7, 8, 'W')
        @t.rate!
      end

      it "should agree with ICU rating database" do
        [
          [1,  3.00, 2174],
          [2,  1.36, 1182],
          [3,  0.85,  851],
          [4,  2.38, 1206],
          [5,  1.05,  717],
          [6,  1.04,  678],
          [7,  1.09,  763],
          [8,  1.24,  805],
        ].each do |item|
          num, expected_score, new_rating = item
          p = @t.player(num)
          p.expected_score.should be_within(0.01).of(expected_score)
          p.new_rating.should be_within(0.5).of(new_rating)
        end
      end
    end

    context "#rate - a tournament with only rated players that included one player who received a bonus" do
      # 1   Howley, Kieran  3509    4      2:W   3:W   4:L   5:W   6:W
      # 2   O'Brien, Pat    12057   3      1:L   3:L   4:W   5:W   6:W
      # 3   Eyers, Michael  6861    2.5    1:L   2:W   4:L   5:W   6:D
      # 4   Guinan, Sean    12161   2.5    1:W   2:L   3:W   5:L   6:D
      # 5   Cooke, Frank    10771   1.5    1:L   2:L   3:L   4:W   6:D
      # 6   Benson, Nicola  6916    1.5    1:L   2:L   3:D   4:D   5:D
      before(:all) do
        @t = ICU::RatedTournament.new(:desc => "Drogheda Club Championship, 2009, Section G")
        @t.add_player(1, :desc => 'Howley, Kieran', :rating => 1046, :kfactor => 24)
        @t.add_player(2, :desc => "O'Brien, Pat",   :rating =>  953, :kfactor => 24)
        @t.add_player(3, :desc => 'Eyers, Michael', :rating =>  922, :kfactor => 32)
        @t.add_player(4, :desc => 'Guinan, Sean',   :rating =>  760, :kfactor => 40)
        @t.add_player(5, :desc => 'Cooke, Frank',   :rating =>  825, :kfactor => 32)
        @t.add_player(6, :desc => 'Benson, Nicola', :rating => 1002, :kfactor => 32)

        @t.add_result(1, 1, 6, 'W')
        @t.add_result(1, 2, 5, 'W')
        @t.add_result(1, 3, 4, 'L')
        @t.add_result(2, 6, 4, 'D')
        @t.add_result(2, 5, 3, 'L')
        @t.add_result(2, 1, 2, 'W')
        @t.add_result(3, 2, 6, 'W')
        @t.add_result(3, 3, 1, 'L')
        @t.add_result(3, 4, 5, 'L')
        @t.add_result(4, 6, 5, 'D')
        @t.add_result(4, 1, 4, 'L')
        @t.add_result(4, 2, 3, 'L')
        @t.add_result(5, 3, 6, 'D')
        @t.add_result(5, 4, 2, 'L')
        @t.add_result(5, 5, 1, 'L')

        @t.rate!
      end

      it "should agree with ICU rating database" do
        [
          [1, 4.0, 3.43, 1060,  0], # Howley
          [2, 3.0, 2.70,  960,  0], # O'Brien
          [3, 2.5, 2.44,  924,  0], # Eyers
          [4, 2.5, 1.30,  824, 16], # Guinan
          [5, 1.5, 1.67,  819,  0], # Cooke
          [6, 1.5, 3.09,  951,  0], # Benson
        ].each do |item|
          num, score, expected_score, new_rating, bonus = item
          p = @t.player(num)
          p.score.should == score
          p.expected_score.should be_within(0.01).of(expected_score)
          p.new_rating.should be_within(0.5).of(new_rating)
          p.bonus.should == bonus
        end
      end

      it "players eligible for a bonus should have pre-bonus data" do
        [
          [1, false], # Howley
          [2, false], # O'Brien
          [3,  true], # Eyers
          [4,  true], # Guinan
          [5,  true], # Cooke
          [6,  true], # Benson
        ].each do |item|
          num, pre_bonus = item
          p = @t.player(num)
          if pre_bonus
            p.pb_rating.should be_kind_of Fixnum
            p.pb_performance.should be_kind_of Fixnum
          else
            p.pb_rating.should be_nil
            p.pb_performance.should be_nil
          end
        end
      end
    end

    context "#rate - a tournament with one rated player who got a bonus and the rest foreigners" do
      # 1   Magee, Ronan          10470   6      8:L   0:+   3:W   0:+   5:L   7:W   6:W   4:W   2:L
      # 2   Antal Tibor, Kende    17014   1      0:    0:    0:    0:    0:    0:    0:    0:    1:W
      # 3   Arsic, Djordje        17015   0      0:    0:    1:L   0:    0:    0:    0:    0:    0:
      # 4   Donchenko, Alexander  17016   0      0:    0:    0:    0:    0:    0:    0:    1:L   0:
      # 5   Emdin, Mark           17017   1      0:    0:    0:    0:    1:W   0:    0:    0:    0:
      # 6   Lushnikov, Evgeny     17018   0      0:    0:    0:    0:    0:    0:    1:L   0:    0:
      # 7   Pulpan, Jakub         17019   0      0:    0:    0:    0:    0:    1:L   0:    0:    0:
      # 8   Toma, Radu-Cristian   17020   1      1:W   0:    0:    0:    0:    0:    0:    0:    0:
      before(:all) do
        @t = ICU::RatedTournament.new(:desc => "European Youth Chess Championships, 2008")
        @t.add_player(1, :desc => 'Magee, Ronan',         :rating => 1667, :kfactor => 40)
        @t.add_player(2, :desc => "Antal Tibor, Kende",   :rating => 2036)
        @t.add_player(3, :desc => 'Arsic, Djordje',       :rating => 1790)
        @t.add_player(4, :desc => 'Donchenko, Alexander', :rating => 1832)
        @t.add_player(5, :desc => 'Emdin, Mark',          :rating => 1832)
        @t.add_player(6, :desc => 'Lushnikov, Evgeny',    :rating => 1939)
        @t.add_player(7, :desc => 'Pulpan, Jakub',        :rating => 1955)
        @t.add_player(8, :desc => 'Toma, Radu-Cristian',  :rating => 1893)

        @t.add_result(1, 1, 8, 'L')
        @t.add_result(3, 1, 3, 'W')
        @t.add_result(5, 1, 5, 'L')
        @t.add_result(6, 1, 7, 'W')
        @t.add_result(7, 1, 6, 'W')
        @t.add_result(8, 1, 4, 'W')
        @t.add_result(9, 1, 2, 'L')

        @t.rate!
      end

      it "should agree with ICU rating database except for new ratings of foreigners" do
        [
          [1, 4.0, 1.54, 1954], # Magee
          [2, 1.0, 0.76, 2236], # Antal
          [3, 0.0, 0.43, 1436], # Arsic
          [4, 0.0, 0.49, 1436], # Donchenko
          [5, 1.0, 0.49, 2236], # Emdin
          [6, 0.0, 0.64, 1436], # Lushnikov
          [7, 0.0, 0.66, 1436], # Pulpan
          [8, 1.0, 0.58, 2236], # Toma
        ].each do |item|
          num, score, expected_score, performance = item
          p = @t.player(num)
          p.score.should == score
          p.expected_score.should be_within(0.01).of(expected_score)
          p.performance.should be_within(0.5).of(performance)
          if num == 1
            p.new_rating.should be_within(0.5).of(1836)
            p.bonus.should == 71
          else
            p.new_rating.should == p.rating
          end
        end
      end
      
      it "players eligible for a bonus should have pre-bonus data" do
        p = @t.player(1)
        p.pb_rating.should be_kind_of Fixnum
        p.pb_performance.should be_kind_of Fixnum
      end
    end

    context "#rate - a tournament with a one provisional and one player who got a bonus" do
      # 1   Blake, Austin           3403    3.5    6:D   2:D   3:W   4:W   5:D
      # 2   Fitzpatrick, Kevin      6968    4      5:W   1:D   6:D   3:W   4:W
      # 3   George Rajesh, Nikhil   10411   1      4:W   5:L   1:L   2:L   6:L
      # 4   Mullooly, Sean          6721    0      3:L   6:L   5:L   1:L   2:L
      # 5   Mullooly, Michael       6623    3.5    2:L   3:W   4:W   6:W   1:D
      # 6   O'Dwyer, Eoin           5931    3      1:D   4:W   2:D   5:L   3:W
      before(:all) do
        @t = ICU::RatedTournament.new(:desc => "Drogheda Congress Sec 5 2007")
        @t.add_player(1, :desc => 'Austin Blake (3403)',          :rating => 1081, :kfactor => 24)
        @t.add_player(2, :desc => 'Kevin Fitzpatrick (6968)',     :rating => 1026, :kfactor => 32)
        @t.add_player(3, :desc => 'Nikhil George Rajesh (10411)', :rating =>  603, :games   =>  5)
        @t.add_player(4, :desc => 'Sean Mullooly (6721)',         :rating =>  568, :kfactor => 40)
        @t.add_player(5, :desc => 'Michael Mullooly (6623)',      :rating =>  719, :kfactor => 40)
        @t.add_player(6, :desc => "Eoin O'Dwyer (5931)",          :rating => 1032, :kfactor => 40)

        @t.add_result(1, 1, 6, 'D')
        @t.add_result(1, 2, 5, 'W')
        @t.add_result(1, 3, 4, 'W')
        @t.add_result(2, 6, 4, 'W')
        @t.add_result(2, 5, 3, 'W')
        @t.add_result(2, 1, 2, 'D')
        @t.add_result(3, 6, 2, 'D')
        @t.add_result(3, 3, 1, 'L')
        @t.add_result(3, 4, 5, 'L')
        @t.add_result(4, 5, 6, 'W')
        @t.add_result(4, 1, 4, 'W')
        @t.add_result(4, 2, 3, 'W')
        @t.add_result(5, 3, 6, 'L')
        @t.add_result(5, 4, 2, 'L')
        @t.add_result(5, 5, 1, 'D')

        @t.rate!
      end

      it "should agree with ICU rating database" do
        [
          [1, 3.5, 3.84,  977, 1073,   0], # Austin
          [2, 4.0, 3.51, 1068, 1042,   0], # Kevin
          [3, 1.0, 1.05,  636,  636, nil], # Nikhil
          [4, 0.0, 0.78,  520,  537,   0], # Sean
          [5, 3.5, 1.74, 1026,  835,  45], # Michael
          [6, 3.0, 3.54,  907, 1010,   0], # Eoin
        ].each do |item|
          num, score, expected_score, performance, new_rating, bonus = item
          p = @t.player(num)
          p.score.should == score
          p.bonus.should == bonus if bonus
          p.performance.should be_within(0.5).of(performance)
          p.expected_score.should be_within(0.01).of(expected_score)
          p.new_rating.should be_within(0.5).of(new_rating)
        end
      end
    end

    context "#rate - a tournament with a mixture of player types that included 2 players who received bonuses" do
      # 1   Fanjimni, Kayode Daniel 12221   4      2:L   3:W   4:-   5:W   6:W   7:W
      # 2   Guinan, Cian            12160   3.5    1:W   3:D   4:W   5:-   6:L   7:W
      # 3   Duffy, Sinead           12185   3.5    1:L   2:D   4:-   5:W   6:W   7:W
      # 4   Cooke, Peter            12169   1      1:-   2:L   3:-   5:L   6:W   7:-
      # 5   Callaghan, Tony         10728   1      1:L   2:-   3:L   4:W   6:-   7:-
      # 6   Montenegro, May Yol     10901   1      1:L   2:W   3:L   4:L   5:-   7:-
      # 7   Lowry-O'Reilly, Johanna 5535    0      1:L   2:L   3:L   4:-   5:-   6:-
      before(:all) do
        @t = ICU::RatedTournament.new(:desc => "Drogheda Club Championship, 2009, Section H")
        @t.add_player(1, :desc => 'Fanjimni, Kayode Daniel', :rating => 1079, :games => 17)
        @t.add_player(2, :desc => 'Guinan, Cian',            :rating =>  659, :kfactor => 40)
        @t.add_player(3, :desc => 'Duffy, Sinead',           :rating =>  731, :kfactor => 40)
        @t.add_player(4, :desc => 'Cooke, Peter',            :rating =>  728, :kfactor => 40)
        @t.add_player(5, :desc => 'Callaghan, Tony',         :rating =>  894, :games => 5)
        @t.add_player(6, :desc => 'Montenegro, May Yol')
        @t.add_player(7, :desc => "Lowry-O'Reilly, Johanna", :rating =>  654, :kfactor => 24)

        @t.add_result(1, 2, 7, 'W')
        @t.add_result(1, 3, 6, 'W')
        @t.add_result(1, 4, 5, 'L')
        @t.add_result(2, 6, 4, 'L')
        @t.add_result(2, 7, 3, 'L')
        @t.add_result(2, 1, 2, 'L')
        @t.add_result(3, 3, 1, 'L')
        @t.add_result(4, 2, 3, 'D')
        @t.add_result(5, 4, 2, 'L')
        @t.add_result(5, 5, 1, 'L')
        @t.add_result(6, 1, 6, 'W')
        @t.add_result(7, 5, 3, 'L')
        @t.add_result(7, 6, 2, 'W')
        @t.add_result(7, 7, 1, 'L')

        @t.rate!

        @m = [
          # MSAccess results taken from rerun of original which is different (reason unknown).
          [1, 4.0, 4.28, 1052, 1052, nil], # Fanjini
          [2, 3.5, 1.93,  920,  757,  35], # Guinan
          [3, 3.5, 2.29,  932,  798,  18], # Duffy
          [4, 1.0, 1.52,  588,  707,   0], # Cooke
          [5, 1.0, 1.40,  828,  828, nil], # Callaghan
          [6, 1.0, 0.91,  627,  627, nil], # Montenegro
          [7, 0.0, 0.78,  460,  635,   0], # Lowry-O'Reilly
        ]
      end

      it "should agree with ICU rating database" do
        @m.each do |item|
          num, score, expected_score, performance, new_rating, bonus = item
          p = @t.player(num)
          p.score.should == score
          p.bonus.should == bonus if bonus
          p.performance.should be_within(num == 2 ? 0.6 : 0.5).of(performance)
          p.expected_score.should be_within(0.01).of(expected_score)
          p.new_rating.should be_within(0.5).of(new_rating)
        end
      end

      it "should give the same results if rated twice" do
        @t.rate!
        @m.each do |item|
          num, score, expected_score, performance, new_rating, bonus = item
          p = @t.player(num)
          p.score.should == score
          p.bonus.should == bonus if bonus
          p.performance.should be_within(num == 2 ? 0.6 : 0.5).of(performance)
          p.expected_score.should be_within(0.01).of(expected_score)
          p.new_rating.should be_within(0.5).of(new_rating)
        end
      end

      it "should be completely different if bonuses are turned off" do
        @t.no_bonuses = true
        @t.rate!
        @m.each do |item|
          num, score, expected_score, performance, new_rating, bonus = item
          p = @t.player(num)
          p.score.should == score
          p.bonus.should == 0 if bonus
          p.performance.should_not be_within(1.0).of(performance)
          p.expected_score.should_not be_within(0.01).of(expected_score)
          p.new_rating.should_not be_within(1.0).of(new_rating)
        end
      end
    end

    context "#rate - a made-up tournament that includes a group of unrateable players" do
      #   1   Orr, Mark               1350    2      2:W   3:W   0:-
      #   2   Coughlan, Anne          251     1      1:L   0:-   3:W
      #   3   Martin, Ryan            6988    0      0:-   1:L   2:L
      #   4   Hanley, Gerard          5701    2      5:W   6:W   0:-
      #   7   Meeny, Kevin            5507    1      4:L   0:-   6:W
      #   8   Prior, Alo              12314   0      0:-   4:L   5:L
      # Used in an experiment to prove the rating database skips unrateable games.
      # See the README and test3.txt in the SVN repository ICU/data/etc/experiments.
      before(:all) do
        @t = ICU::RatedTournament.new(:desc => "Unrateable Test 3")
        @t.add_player(1, :desc => 'Orr, Mark',               :rating => 2174, :kfactor => 16)  # rated
        @t.add_player(2, :desc => 'Coughlan, Anne',          :rating => 1182, :kfactor => 24)  # rated
        @t.add_player(3, :desc => 'Martin, Ryan',            :rating =>  717, :games   => 13)  # provisional
        @t.add_player(4, :desc => 'Hanley, Gerard',          :rating =>  678, :games   => 13)  # provisional
        @t.add_player(5, :desc => 'Meeny, Kevin')                                              # unrated
        @t.add_player(6, :desc => 'Prior, Alo')                                                # unrated
        @t.add_result(1, 1, 2, 'W')
        @t.add_result(1, 4, 5, 'W')
        @t.add_result(2, 1, 3, 'W')
        @t.add_result(2, 4, 6, 'W')
        @t.add_result(3, 2, 3, 'W')
        @t.add_result(3, 5, 6, 'W')
        @t.rate!
      end

      it "should agree with ICU rating database for rateable players" do
        [
          [1,  2.00, 2174],
          [2,  0.91, 1184],
          [3,  0.10,  792],
        ].each do |item|
          num, expected_score, new_rating = item
          p = @t.player(num)
          p.expected_score.should be_within(0.01).of(expected_score)
          p.new_rating.should be_within(0.5).of(new_rating)
        end
      end

      it "should not rate players that have no rateable games" do
        [4, 5, 6].each do |num|
          p = @t.player(num)
          p.expected_score.should == 0.0
          p.new_rating.should be_nil
        end
      end
    end

    context "#rate - Glegowski and Galligan in LCU Div 3 2012" do
      before(:each) do
        @t = ICU::RatedTournament.new(desc: 'LCU Div 3 2011-12', no_bonuses: false)

        # The two player's we are most interested in. The problem that led to
        # this test was later tracked to Glegowski's K-factor (either 24 or 32).
        @t.add_player(1, kfactor: 24, rating: 1424, desc: 'Cezary Glegolski (10620)')
        @t.add_player(2,                            desc: 'Sean Galligan (13021)')

        # Cezary Glegolski opponents.
        @t.add_player(101, kfactor: 24, rating: 1436, desc: 'Michael Dempsey (323)')
        @t.add_player(102, kfactor: 24, rating: 1590, desc: 'Michael D. Keating (2216)')
        @t.add_player(103, kfactor: 40, rating: 1648, desc: 'Ben Quigley (5218)')
        @t.add_player(104, kfactor: 24, rating: 1664, desc: 'Michael Hanley (536)')
        @t.add_player(105, kfactor: 24, rating: 1492, desc: 'Sean Loftus (788)')
        @t.add_player(106, kfactor: 24, rating: 1503, desc: 'Garret Curran (1712)')
        @t.add_player(107, kfactor: 24, rating: 1692, desc: 'Ernie McElroy (1080)')
        @t.add_player(108, kfactor: 24, rating: 1681, desc: 'Sean Nolan (4572)')
        @t.add_player(109, kfactor: 24, rating: 1639, desc: 'Paul Taaffe (2217)')
        @t.add_player(110, kfactor: 24, rating: 1729, desc: 'Kieran Rogers (4028)')

        # Sean Galligan's opponents.
        # 105
        # 106
        # 107
        @t.add_player(204, kfactor: 24, rating: 1923, desc: 'Brian Gallagher (468)')
        # 109
        @t.add_player(206, kfactor: 24, rating: 1764, desc: 'Rick Goetzee (7190)')
        # 104
        @t.add_player(208, kfactor: 24, rating: 1692, desc: 'Colm Buckley (117))')
        # 102
        @t.add_player(210, kfactor: 24, rating: 1575, desc: 'John Quigley (1393)')

        # Results.
        @t.add_result(1,  1, 101, "D")
        @t.add_result(2,  1, 102, "W")
        @t.add_result(3,  1, 103, "W")
        @t.add_result(4,  1, 104, "W")
        @t.add_result(5,  1, 105, "W")
        @t.add_result(6,  1, 106, "W")
        @t.add_result(7,  1, 107, "W")
        @t.add_result(8,  1, 108, "L")
        @t.add_result(9,  1, 109, "L")
        @t.add_result(10, 1, 110, "L")
        @t.add_result(11, 1,   2, "L")
        @t.add_result(1,  2, 105, "D")
        @t.add_result(2,  2, 106, "D")
        @t.add_result(3,  2, 107, "D")
        @t.add_result(4,  2, 204, "D")
        @t.add_result(5,  2, 109, "D")
        @t.add_result(6,  2, 206, "W")
        @t.add_result(7,  2, 104, "W")
        @t.add_result(8,  2, 208, "L")
        @t.add_result(9,  2, 102, "D")
        @t.add_result(10, 2, 210, "D")
        @t.add_result(11, 2,   1, "W")

        # Get the two players of interest.
        @p1 = @t.player(1)
        @p2 = @t.player(2)
      end

      it "should behave like the Access system" do
        @t.rate!
        @p1.new_rating.should be_within(0.5).of(1511)
        @p1.expected_score.should be_within(0.001).of(2.868)
        @p1.bonus.should == 0
        @p2.new_rating.should be_within(0.5).of(1705)
      end

      it "should behave like ratings.ciu.ie" do
        @p1.instance_eval { @kfactor = 32 }
        @t.rate!
        @p1.new_rating.should be_within(0.5).of(1603)
        @p1.expected_score.should be_within(0.001).of(2.868)
        @p1.bonus.should be_within(1).of(63)
        @p2.new_rating.should be_within(0.5).of(1722)
      end
    end

    context "#rate - Jonathan Peoples in the Irish Junior U12 Championships 2012" do
      before(:each) do
        @t = ICU::RatedTournament.new(desc: 'Irish U12 Junior Championships 2012')

        @t.add_player(4289, desc: "Jeffrey Alfred",        rating: 1090, kfactor: 40)
        @t.add_player(4290, desc: "Piotr Baczkowski",      rating:  557, games:   10)
        @t.add_player(4291, desc: "Ross Beatty",           rating:  890, games:   17)
        @t.add_player(4292, desc: "Katherine Bolger")
        @t.add_player(4293, desc: "Liam Coman",            rating:  415, games:   16)
        @t.add_player(4294, desc: "Darragh Flynn",         rating:  320, kfactor: 40)
        @t.add_player(4295, desc: "David Halpenny",        rating:  794, games:    8)
        @t.add_player(4296, desc: "Will Hartery",          rating:  288, games:   18)
        @t.add_player(4297, desc: "Michael Higgins",       rating:  839, kfactor: 40)
        @t.add_player(4298, desc: "Padraig Hughes",        rating: 1385, kfactor: 40)
        @t.add_player(4299, desc: "Mihailo Manojlovic",    rating:  742, kfactor: 40)
        @t.add_player(4300, desc: "Joe McEntegert")
        @t.add_player(4301, desc: "Tom McGrath",           rating: 1058, kfactor: 40)
        @t.add_player(4302, desc: "Colin McKenna")
        @t.add_player(4303, desc: "Thomas McStay",         rating:  234, games:    6)
        @t.add_player(4304, desc: "Shane Melaugh",         rating:  683, kfactor: 40)
        @t.add_player(4305, desc: "Diana Mirza",           rating: 1485, kfactor: 40)
        @t.add_player(4306, desc: "Keerthi Mohan",         rating:  336, games:    5)
        @t.add_player(4307, desc: "Ellen Murray",          rating:  126, games:   11)
        @t.add_player(4308, desc: "Eibhia Ni Mhuireagain", rating:  864, kfactor: 40)
        @t.add_player(4309, desc: "Joe O'Neill")
        @t.add_player(4310, desc: "Jim O'Reilly",          rating:  782, kfactor: 40)
        @t.add_player(4311, desc: "Jonathon Peoples")
        @t.add_player(4312, desc: "Nobin Rebi")
        @t.add_player(4313, desc: "Fiachra Scallan",       rating: 1000, kfactor: 40)
        @t.add_player(4314, desc: "Shanly Sebastian")
        @t.add_player(4315, desc: "Finnian Wingfield")

        @t.add_result(1, 4289, 4307, "W")
        @t.add_result(1, 4290, 4309, "W")
        @t.add_result(1, 4291, 4311, "W")
        @t.add_result(1, 4292, 4312, "L")
        @t.add_result(1, 4293, 4303, "D")
        @t.add_result(1, 4294, 4314, "W")
        @t.add_result(1, 4295, 4305, "L")
        @t.add_result(1, 4296, 4298, "L")
        @t.add_result(1, 4297, 4306, "W")
        @t.add_result(1, 4298, 4296, "W")
        @t.add_result(1, 4299, 4301, "W")
        @t.add_result(1, 4300, 4310, "L")
        @t.add_result(1, 4301, 4299, "L")
        @t.add_result(1, 4302, 4313, "L")
        @t.add_result(1, 4303, 4293, "D")
        @t.add_result(1, 4304, 4308, "L")
        @t.add_result(1, 4305, 4295, "W")
        @t.add_result(1, 4306, 4297, "L")
        @t.add_result(1, 4307, 4289, "L")
        @t.add_result(1, 4308, 4304, "W")
        @t.add_result(1, 4309, 4290, "L")
        @t.add_result(1, 4310, 4300, "W")
        @t.add_result(1, 4311, 4291, "L")
        @t.add_result(1, 4312, 4292, "W")
        @t.add_result(1, 4313, 4302, "W")
        @t.add_result(1, 4314, 4294, "L")
        @t.add_result(2, 4290, 4305, "L")
        @t.add_result(2, 4291, 4308, "D")
        @t.add_result(2, 4292, 4302, "W")
        @t.add_result(2, 4293, 4301, "L")
        @t.add_result(2, 4294, 4313, "L")
        @t.add_result(2, 4295, 4306, "W")
        @t.add_result(2, 4296, 4307, "W")
        @t.add_result(2, 4297, 4315, "W")
        @t.add_result(2, 4298, 4314, "W")
        @t.add_result(2, 4299, 4310, "D")
        @t.add_result(2, 4300, 4309, "W")
        @t.add_result(2, 4301, 4293, "W")
        @t.add_result(2, 4302, 4292, "L")
        @t.add_result(2, 4303, 4312, "W")
        @t.add_result(2, 4304, 4311, "L")
        @t.add_result(2, 4305, 4290, "W")
        @t.add_result(2, 4306, 4295, "L")
        @t.add_result(2, 4307, 4296, "L")
        @t.add_result(2, 4308, 4291, "D")
        @t.add_result(2, 4309, 4300, "L")
        @t.add_result(2, 4310, 4299, "D")
        @t.add_result(2, 4311, 4304, "W")
        @t.add_result(2, 4312, 4303, "L")
        @t.add_result(2, 4313, 4294, "W")
        @t.add_result(2, 4314, 4298, "L")
        @t.add_result(2, 4315, 4297, "L")
        @t.add_result(3, 4289, 4291, "W")
        @t.add_result(3, 4290, 4311, "L")
        @t.add_result(3, 4291, 4289, "L")
        @t.add_result(3, 4292, 4315, "L")
        @t.add_result(3, 4293, 4302, "W")
        @t.add_result(3, 4294, 4300, "L")
        @t.add_result(3, 4295, 4312, "W")
        @t.add_result(3, 4296, 4301, "L")
        @t.add_result(3, 4297, 4298, "L")
        @t.add_result(3, 4298, 4297, "W")
        @t.add_result(3, 4299, 4308, "W")
        @t.add_result(3, 4300, 4294, "W")
        @t.add_result(3, 4301, 4296, "W")
        @t.add_result(3, 4302, 4293, "L")
        @t.add_result(3, 4303, 4310, "L")
        @t.add_result(3, 4304, 4307, "W")
        @t.add_result(3, 4305, 4313, "D")
        @t.add_result(3, 4306, 4309, "L")
        @t.add_result(3, 4307, 4304, "L")
        @t.add_result(3, 4308, 4299, "L")
        @t.add_result(3, 4309, 4306, "W")
        @t.add_result(3, 4310, 4303, "W")
        @t.add_result(3, 4311, 4290, "W")
        @t.add_result(3, 4312, 4295, "L")
        @t.add_result(3, 4313, 4305, "D")
        @t.add_result(3, 4315, 4292, "W")
        @t.add_result(4, 4289, 4299, "L")
        @t.add_result(4, 4290, 4312, "D")
        @t.add_result(4, 4291, 4303, "W")
        @t.add_result(4, 4292, 4304, "L")
        @t.add_result(4, 4293, 4308, "L")
        @t.add_result(4, 4294, 4309, "L")
        @t.add_result(4, 4295, 4315, "W")
        @t.add_result(4, 4296, 4314, "W")
        @t.add_result(4, 4297, 4300, "W")
        @t.add_result(4, 4298, 4305, "W")
        @t.add_result(4, 4299, 4289, "W")
        @t.add_result(4, 4300, 4297, "L")
        @t.add_result(4, 4301, 4311, "W")
        @t.add_result(4, 4302, 4306, "W")
        @t.add_result(4, 4303, 4291, "L")
        @t.add_result(4, 4304, 4292, "W")
        @t.add_result(4, 4305, 4298, "L")
        @t.add_result(4, 4306, 4302, "L")
        @t.add_result(4, 4308, 4293, "W")
        @t.add_result(4, 4309, 4294, "W")
        @t.add_result(4, 4310, 4313, "L")
        @t.add_result(4, 4311, 4301, "L")
        @t.add_result(4, 4312, 4290, "D")
        @t.add_result(4, 4313, 4310, "W")
        @t.add_result(4, 4314, 4296, "L")
        @t.add_result(4, 4315, 4295, "L")
        @t.add_result(5, 4289, 4310, "W")
        @t.add_result(5, 4290, 4293, "D")
        @t.add_result(5, 4291, 4296, "W")
        @t.add_result(5, 4292, 4307, "D")
        @t.add_result(5, 4293, 4290, "D")
        @t.add_result(5, 4294, 4312, "W")
        @t.add_result(5, 4295, 4297, "L")
        @t.add_result(5, 4296, 4291, "L")
        @t.add_result(5, 4297, 4295, "W")
        @t.add_result(5, 4298, 4299, "D")
        @t.add_result(5, 4299, 4298, "D")
        @t.add_result(5, 4300, 4311, "L")
        @t.add_result(5, 4301, 4313, "D")
        @t.add_result(5, 4302, 4314, "W")
        @t.add_result(5, 4303, 4315, "W")
        @t.add_result(5, 4304, 4309, "L")
        @t.add_result(5, 4305, 4308, "W")
        @t.add_result(5, 4307, 4292, "D")
        @t.add_result(5, 4308, 4305, "L")
        @t.add_result(5, 4309, 4304, "W")
        @t.add_result(5, 4310, 4289, "L")
        @t.add_result(5, 4311, 4300, "W")
        @t.add_result(5, 4312, 4294, "L")
        @t.add_result(5, 4313, 4301, "D")
        @t.add_result(5, 4314, 4302, "L")
        @t.add_result(5, 4315, 4303, "L")
        @t.add_result(6, 4289, 4301, "L")
        @t.add_result(6, 4290, 4304, "D")
        @t.add_result(6, 4291, 4305, "W")
        @t.add_result(6, 4292, 4314, "D")
        @t.add_result(6, 4293, 4300, "D")
        @t.add_result(6, 4294, 4302, "W")
        @t.add_result(6, 4295, 4311, "W")
        @t.add_result(6, 4296, 4315, "W")
        @t.add_result(6, 4297, 4299, "W")
        @t.add_result(6, 4298, 4313, "W")
        @t.add_result(6, 4299, 4297, "L")
        @t.add_result(6, 4300, 4293, "D")
        @t.add_result(6, 4301, 4289, "W")
        @t.add_result(6, 4302, 4294, "L")
        @t.add_result(6, 4303, 4308, "L")
        @t.add_result(6, 4304, 4290, "D")
        @t.add_result(6, 4305, 4291, "L")
        @t.add_result(6, 4307, 4312, "W")
        @t.add_result(6, 4308, 4303, "W")
        @t.add_result(6, 4309, 4310, "L")
        @t.add_result(6, 4310, 4309, "W")
        @t.add_result(6, 4311, 4295, "L")
        @t.add_result(6, 4312, 4307, "L")
        @t.add_result(6, 4313, 4298, "L")
        @t.add_result(6, 4314, 4292, "D")
        @t.add_result(6, 4315, 4296, "L")

        # Get the players of interest (Jonathan Peoples and his opponents).
        @p  = @t.player(4311)
        @o1 = @t.player(4291)
        @o2 = @t.player(4304)
        @o3 = @t.player(4290)
        @o4 = @t.player(4301)
        @o5 = @t.player(4300)
        @o6 = @t.player(4295)
      end

      it "should be setup properly" do
        @p.desc.should  == "Jonathon Peoples"
        @o1.desc.should == "Ross Beatty"
        @o2.desc.should == "Shane Melaugh"
        @o3.desc.should == "Piotr Baczkowski"
        @o4.desc.should == "Tom McGrath"
        @o5.desc.should == "Joe McEntegert"
        @o6.desc.should == "David Halpenny"

        @p.type.should  == :unrated
        @o1.type.should == :provisional
        @o2.type.should == :rated
        @o3.type.should == :provisional
        @o4.type.should == :rated
        @o5.type.should == :unrated
        @o6.type.should == :provisional

        @o2.rating.should == 683
        @o4.rating.should == 1058

        @t.iterations1.should be_nil
        @t.iterations2.should be_nil
      end

      it "should produce inconsistent results with original algorithm" do
        @t.rate!

        @p.new_rating.should be_within(0.5).of(763)  # the original calculation

        @o1.new_rating.should == @o1.performance
        @o2.bonus.should == 0
        @o3.new_rating.should == @o3.performance
        @o4.bonus.should == 0
        @o5.new_rating.should == @o5.performance
        @o6.new_rating.should == @o6.performance

        ratings = [@o1, @o2, @o3, @o4, @o5, @o6].map { |o| o.new_rating(:opponent) }

        average_of_ratings = ratings.inject(0.0){ |m,r| m = m + r } / 6.0
        average_of_ratings.should_not be_within(0.5).of(@p.new_rating)

        @t.iterations1.should be > 1
        @t.iterations2.should == 1
      end

      it "should produce consistent results with version 1 algorithm" do
        @t.rate!(version: 1)

        @p.new_rating.should_not be_within(0.5).of(763)  # the new calculation is different

        @o1.new_rating.should == @o1.performance
        @o2.bonus.should == 0
        @o3.new_rating.should == @o3.performance
        @o4.bonus.should == 0
        @o5.new_rating.should == @o5.performance
        @o6.new_rating.should == @o6.performance

        ratings = [@o1, @o2, @o3, @o4, @o5, @o6].map { |o| o.new_rating(:opponent) }

        average_of_ratings = ratings.inject(0.0){ |m,r| m = m + r } / 6.0
        average_of_ratings.should be_within(0.5).of(@p.new_rating)

        @t.iterations1.should be > 1
        @t.iterations2.should be > 1
      end
    end

    context "#rate - Sasha-Ettore Faleschini in the Bunratty Minor 2012" do
      before(:each) do
        @t = ICU::RatedTournament.new(desc: "Bunratty Minor 2012")

        # Add the players of most interest (Sasha-Ettore Faleschini and his opponents).
        @p  = @t.add_player(1752, desc: "Sasha-Ettore Faleschini")
        @o1 = @t.add_player(1748, desc: "John P. Dunne",      rating:  946, kfactor: 40)
        @o2 = @t.add_player(1755, desc: "Jack Fitzgerald",    rating:  913, kfactor: 40)
        @o3 = @t.add_player(1766, desc: "Mikolaj Glegolski",  rating:  841, kfactor: 40)
        @o4 = @t.add_player(1732, desc: "Daniel Boland",      rating:  793, kfactor: 40)
        @o5 = @t.add_player(1776, desc: "Noel Keating",       rating:  667, kfactor: 32)
        @o6 = @t.add_player(1798, desc: "Cathal Minnock",     rating:  917, kfactor: 40)

        # Add all the other players.
        @t.add_player(1730, desc: "Jeffrey Alfred",           rating: 1058, kfactor: 40)
        @t.add_player(1731, desc: "Suliman Ali",              rating: 1166, games:   17)
        @t.add_player(1733, desc: "Dylan Boland")
        @t.add_player(1734, desc: "Shane Briggs",             rating: 1079, kfactor: 24)
        @t.add_player(1735, desc: "Joe Browne",               rating:  919, kfactor: 24)
        @t.add_player(1736, desc: "Kieran Burke",             rating:  765, games:   10)
        @t.add_player(1737, desc: "Liam Cadogan",             rating: 1002, kfactor: 24)
        @t.add_player(1738, desc: "Evan Cahill",              rating:  494, games:    4)
        @t.add_player(1739, desc: "Joseph Cesar",             rating:  751, kfactor: 40)
        @t.add_player(1740, desc: "Joshua Cesar",             rating:  403, games:   10)
        @t.add_player(1741, desc: "John G. Connolly",         rating:  952, kfactor: 32)
        @t.add_player(1742, desc: "Fiona Cormican",           rating:  483, kfactor: 32)
        @t.add_player(1743, desc: "Joe Cronin",               rating:  601, games:    6)
        @t.add_player(1744, desc: "Aaron Daly",               rating:  699, games:   12)
        @t.add_player(1745, desc: "Conor Devilly",            rating:  676, kfactor: 40)
        @t.add_player(1746, desc: "Charles Dillon")
        @t.add_player(1747, desc: "Jack Donovan")
        @t.add_player(1749, desc: "Thomas Dunne",             rating:  887, kfactor: 32)
        @t.add_player(1750, desc: "Michael Eyers",            rating:  857, kfactor: 32)
        @t.add_player(1751, desc: "Sean Fagan",               rating:  243, games:   10)
        @t.add_player(1753, desc: "Victoria Fennell",         rating:  166, games:   11)
        @t.add_player(1754, desc: "Mark Finn-Lynch")
        @t.add_player(1756, desc: "Peter Fletcher",           rating:  680, games:   18)
        @t.add_player(1757, desc: "Darragh Flynn",            rating:  296, kfactor: 40)
        @t.add_player(1758, desc: "Geordan Freeman",          rating:  413, games:    4)
        @t.add_player(1759, desc: "Ruairi Freeman",           rating:  582, kfactor: 40)
        @t.add_player(1760, desc: "Aoife Gallagher")
        @t.add_player(1761, desc: "Hannah Gallagher")
        @t.add_player(1762, desc: "Tommy Gallagher")
        @t.add_player(1763, desc: "Leslie Garabedian")
        @t.add_player(1764, desc: "Alexander Gillett",        rating:  850, games:   19)
        @t.add_player(1765, desc: "Jan Glegolski",            rating:  525, games:   16)
        @t.add_player(1767, desc: "Mark Halley",              rating: 1280, kfactor: 40)
        @t.add_player(1768, desc: "Siobhan Halley",           rating:  434, games:   18)
        @t.add_player(1769, desc: "Luke Hayden",              rating:  781, games:    6)
        @t.add_player(1770, desc: "Colm Hehir",               rating:  564, games:   16)
        @t.add_player(1771, desc: "Donal Hehir",              rating:  424, games:    6)
        @t.add_player(1772, desc: "Andrew Ingram",            rating:  859, kfactor: 32)
        @t.add_player(1773, desc: "Rory Jackson")
        @t.add_player(1774, desc: "Tom Kearney",              rating:  924, kfactor: 40)
        @t.add_player(1775, desc: "Jamie Kearns",             rating:  753, games:   11)
        @t.add_player(1777, desc: "Thomas Keating",           rating:  864, kfactor: 40)
        @t.add_player(1778, desc: "Darragh Kennedy",          rating: 1052, kfactor: 40)
        @t.add_player(1779, desc: "Stephen Kennedy",          rating:  490, kfactor: 40)
        @t.add_player(1780, desc: "Jonathan Kiely",           rating: 1117, kfactor: 24)
        @t.add_player(1781, desc: "Kevin Kilduff",            rating: 1116, kfactor: 40)
        @t.add_player(1782, desc: "Conor Kirby MacGuill",     rating:  410, games:    9)
        @t.add_player(1783, desc: "Wiktor Kwapinski")
        @t.add_player(1784, desc: "Andrew Kyne-Delaney",      rating:  869, kfactor: 40)
        @t.add_player(1785, desc: "Samuel Lenihan",           rating:  683, kfactor: 40)
        @t.add_player(1786, desc: "Haoang Li",                rating:  667, kfactor: 40)
        @t.add_player(1787, desc: "Stephen Li",               rating:  880, games:   17)
        @t.add_player(1788, desc: "Desmond Martin",           rating: 1018, kfactor: 24)
        @t.add_player(1789, desc: "Clare McCarrick",          rating:  805, kfactor: 40)
        @t.add_player(1790, desc: "Padraig McCullough",       rating:  676, kfactor: 24)
        @t.add_player(1791, desc: "Finn McDonnell",           rating:  740, kfactor: 40)
        @t.add_player(1792, desc: "Odhran McDonnell",         rating:  752, kfactor: 40)
        @t.add_player(1793, desc: "John McGann",              rating:  885, kfactor: 32)
        @t.add_player(1794, desc: "Tom McGrath",              rating: 1076, kfactor: 40)
        @t.add_player(1795, desc: "Robbie Meaney",            rating:  859, kfactor: 40)
        @t.add_player(1796, desc: "Stephen Meaney",           rating:  782, kfactor: 40)
        @t.add_player(1797, desc: "Jacob Miller")
        @t.add_player(1799, desc: "Diarmuid Minnock",         rating:  760, kfactor: 40)
        @t.add_player(1800, desc: "Michael Morgan",           rating:  889, kfactor: 32)
        @t.add_player(1801, desc: "Alex Mulligan",            rating:  603, games:   17)
        @t.add_player(1802, desc: "Scott Mulligan",           rating: 1100, kfactor: 40)
        @t.add_player(1803, desc: "Jessica Mulqueen-Danaher", rating:  286, kfactor: 40)
        @t.add_player(1804, desc: "Christopher Murphy",       rating:  990, kfactor: 40)
        @t.add_player(1805, desc: "Aleksander Nalewajka")
        @t.add_player(1806, desc: "Eibhia Ni Mhuireagain",    rating:  875, kfactor: 40)
        @t.add_player(1807, desc: "Dan O'Brien",              rating:  789, kfactor: 40)
        @t.add_player(1808, desc: "Pat O'Brien",              rating:  970, kfactor: 24)
        @t.add_player(1809, desc: "Michael Joseph O'Connell", rating: 1010, kfactor: 32)
        @t.add_player(1810, desc: "John P. O'Connor",         rating:  242, games:    6)
        @t.add_player(1811, desc: "Ross O'Connor",            rating:  812, kfactor: 40)
        @t.add_player(1812, desc: "Colm O'Muireagain",        rating:  950, kfactor: 32)
        @t.add_player(1813, desc: "Barry O'Reilly",           rating:  736, games:    6)
        @t.add_player(1814, desc: "Jim O'Reilly",             rating:  784, kfactor: 40)
        @t.add_player(1815, desc: "David Piercy",             rating:  970, kfactor: 32)
        @t.add_player(1816, desc: "Agnieszka Pozniak",        rating:  906, kfactor: 40)
        @t.add_player(1817, desc: "Denis Savage")
        @t.add_player(1818, desc: "Fiachra Scallan",          rating:  789, kfactor: 40)
        @t.add_player(1819, desc: "Nick Scallan",             rating: 1034, kfactor: 32)
        @t.add_player(1820, desc: "John Shanley",             rating: 1186, kfactor: 24)
        @t.add_player(1821, desc: "Stephen Sheehan")
        @t.add_player(1822, desc: "Kevin Singpurwala",        rating:  790, kfactor: 40)
        @t.add_player(1823, desc: "Kaj Skubiszak")
        @t.add_player(1824, desc: "Jack Staed",               rating:  133, games:   10)
        @t.add_player(1825, desc: "Devin Tarleton",           rating:  852, games:   11)
        @t.add_player(1826, desc: "M. Thangaramanujam",       rating:  813, kfactor: 24)
        @t.add_player(1827, desc: "Haley Tomlinson")
        @t.add_player(1828, desc: "Peter Urwin",              rating:  848, kfactor: 40)
        @t.add_player(1829, desc: "Cian Wall",                rating:  510, kfactor: 40)
        @t.add_player(1830, desc: "Robert Wall",              rating:  855, kfactor: 24)
        @t.add_player(1831, desc: "Conor Ward")

        # Add results.
        @t.add_result(1, 1730, 1757, "W")
        @t.add_result(1, 1731, 1778, "D")
        @t.add_result(1, 1732, 1797, "W")
        @t.add_result(1, 1733, 1819, "L")
        @t.add_result(1, 1734, 1779, "W")
        @t.add_result(1, 1735, 1758, "W")
        @t.add_result(1, 1736, 1815, "D")
        @t.add_result(1, 1737, 1740, "W")
        @t.add_result(1, 1738, 1808, "L")
        @t.add_result(1, 1739, 1809, "L")
        @t.add_result(1, 1740, 1737, "L")
        @t.add_result(1, 1741, 1746, "W")
        @t.add_result(1, 1742, 1767, "L")
        @t.add_result(1, 1743, 1804, "L")
        @t.add_result(1, 1744, 1755, "W")
        @t.add_result(1, 1745, 1825, "W")
        @t.add_result(1, 1746, 1741, "L")
        @t.add_result(1, 1747, 1781, "L")
        @t.add_result(1, 1748, 1752, "W")
        @t.add_result(1, 1749, 1759, "W")
        @t.add_result(1, 1750, 1764, "W")
        @t.add_result(1, 1751, 1812, "L")
        @t.add_result(1, 1752, 1748, "L")
        @t.add_result(1, 1753, 1774, "L")
        @t.add_result(1, 1754, 1798, "L")
        @t.add_result(1, 1755, 1744, "L")
        @t.add_result(1, 1756, 1794, "L")
        @t.add_result(1, 1757, 1730, "L")
        @t.add_result(1, 1758, 1735, "L")
        @t.add_result(1, 1759, 1749, "L")
        @t.add_result(1, 1760, 1800, "L")
        @t.add_result(1, 1761, 1784, "L")
        @t.add_result(1, 1762, 1806, "L")
        @t.add_result(1, 1763, 1772, "L")
        @t.add_result(1, 1764, 1750, "L")
        @t.add_result(1, 1767, 1742, "W")
        @t.add_result(1, 1768, 1830, "L")
        @t.add_result(1, 1769, 1777, "W")
        @t.add_result(1, 1770, 1826, "W")
        @t.add_result(1, 1771, 1814, "D")
        @t.add_result(1, 1772, 1763, "W")
        @t.add_result(1, 1773, 1795, "L")
        @t.add_result(1, 1774, 1753, "W")
        @t.add_result(1, 1775, 1789, "D")
        @t.add_result(1, 1776, 1828, "L")
        @t.add_result(1, 1777, 1769, "L")
        @t.add_result(1, 1778, 1731, "D")
        @t.add_result(1, 1779, 1734, "L")
        @t.add_result(1, 1780, 1829, "W")
        @t.add_result(1, 1781, 1747, "W")
        @t.add_result(1, 1782, 1811, "W")
        @t.add_result(1, 1784, 1761, "W")
        @t.add_result(1, 1785, 1831, "W")
        @t.add_result(1, 1786, 1817, "W")
        @t.add_result(1, 1788, 1803, "W")
        @t.add_result(1, 1789, 1775, "D")
        @t.add_result(1, 1790, 1827, "W")
        @t.add_result(1, 1791, 1821, "W")
        @t.add_result(1, 1792, 1820, "L")
        @t.add_result(1, 1793, 1816, "L")
        @t.add_result(1, 1794, 1756, "W")
        @t.add_result(1, 1795, 1773, "W")
        @t.add_result(1, 1796, 1813, "W")
        @t.add_result(1, 1797, 1732, "L")
        @t.add_result(1, 1798, 1754, "W")
        @t.add_result(1, 1799, 1802, "L")
        @t.add_result(1, 1800, 1760, "W")
        @t.add_result(1, 1801, 1822, "W")
        @t.add_result(1, 1802, 1799, "W")
        @t.add_result(1, 1803, 1788, "L")
        @t.add_result(1, 1804, 1743, "W")
        @t.add_result(1, 1806, 1762, "W")
        @t.add_result(1, 1807, 1824, "W")
        @t.add_result(1, 1808, 1738, "W")
        @t.add_result(1, 1809, 1739, "W")
        @t.add_result(1, 1810, 1818, "L")
        @t.add_result(1, 1811, 1782, "L")
        @t.add_result(1, 1812, 1751, "W")
        @t.add_result(1, 1813, 1796, "L")
        @t.add_result(1, 1814, 1771, "D")
        @t.add_result(1, 1815, 1736, "D")
        @t.add_result(1, 1816, 1793, "W")
        @t.add_result(1, 1817, 1786, "L")
        @t.add_result(1, 1818, 1810, "W")
        @t.add_result(1, 1819, 1733, "W")
        @t.add_result(1, 1820, 1792, "W")
        @t.add_result(1, 1821, 1791, "L")
        @t.add_result(1, 1822, 1801, "L")
        @t.add_result(1, 1824, 1807, "L")
        @t.add_result(1, 1825, 1745, "L")
        @t.add_result(1, 1826, 1770, "L")
        @t.add_result(1, 1827, 1790, "L")
        @t.add_result(1, 1828, 1776, "W")
        @t.add_result(1, 1829, 1780, "L")
        @t.add_result(1, 1830, 1768, "W")
        @t.add_result(1, 1831, 1785, "L")
        @t.add_result(2, 1730, 1750, "D")
        @t.add_result(2, 1731, 1805, "W")
        @t.add_result(2, 1732, 1809, "L")
        @t.add_result(2, 1733, 1810, "D")
        @t.add_result(2, 1734, 1830, "D")
        @t.add_result(2, 1735, 1802, "L")
        @t.add_result(2, 1736, 1823, "W")
        @t.add_result(2, 1737, 1807, "L")
        @t.add_result(2, 1738, 1817, "L")
        @t.add_result(2, 1739, 1797, "L")
        @t.add_result(2, 1740, 1824, "W")
        @t.add_result(2, 1741, 1791, "L")
        @t.add_result(2, 1742, 1764, "D")
        @t.add_result(2, 1743, 1813, "W")
        @t.add_result(2, 1744, 1774, "W")
        @t.add_result(2, 1745, 1812, "W")
        @t.add_result(2, 1746, 1821, "W")
        @t.add_result(2, 1747, 1827, "W")
        @t.add_result(2, 1748, 1785, "W")
        @t.add_result(2, 1749, 1801, "W")
        @t.add_result(2, 1750, 1730, "D")
        @t.add_result(2, 1751, 1825, "L")
        @t.add_result(2, 1752, 1755, "W")
        @t.add_result(2, 1753, 1793, "L")
        @t.add_result(2, 1754, 1777, "L")
        @t.add_result(2, 1755, 1752, "L")
        @t.add_result(2, 1756, 1826, "D")
        @t.add_result(2, 1757, 1768, "W")
        @t.add_result(2, 1758, 1799, "L")
        @t.add_result(2, 1759, 1811, "L")
        @t.add_result(2, 1760, 1776, "L")
        @t.add_result(2, 1761, 1822, "L")
        @t.add_result(2, 1762, 1792, "L")
        @t.add_result(2, 1763, 1829, "L")
        @t.add_result(2, 1764, 1742, "D")
        @t.add_result(2, 1765, 1778, "L")
        @t.add_result(2, 1766, 1771, "D")
        @t.add_result(2, 1767, 1806, "W")
        @t.add_result(2, 1768, 1757, "L")
        @t.add_result(2, 1769, 1798, "W")
        @t.add_result(2, 1770, 1794, "L")
        @t.add_result(2, 1771, 1766, "D")
        @t.add_result(2, 1772, 1780, "W")
        @t.add_result(2, 1773, 1803, "L")
        @t.add_result(2, 1774, 1744, "L")
        @t.add_result(2, 1775, 1814, "L")
        @t.add_result(2, 1776, 1760, "W")
        @t.add_result(2, 1777, 1754, "W")
        @t.add_result(2, 1778, 1765, "W")
        @t.add_result(2, 1780, 1772, "L")
        @t.add_result(2, 1781, 1790, "W")
        @t.add_result(2, 1782, 1816, "L")
        @t.add_result(2, 1783, 1815, "L")
        @t.add_result(2, 1784, 1820, "W")
        @t.add_result(2, 1785, 1748, "L")
        @t.add_result(2, 1786, 1808, "L")
        @t.add_result(2, 1787, 1789, "W")
        @t.add_result(2, 1788, 1795, "D")
        @t.add_result(2, 1789, 1787, "L")
        @t.add_result(2, 1790, 1781, "L")
        @t.add_result(2, 1791, 1741, "W")
        @t.add_result(2, 1792, 1762, "W")
        @t.add_result(2, 1793, 1753, "W")
        @t.add_result(2, 1794, 1770, "W")
        @t.add_result(2, 1795, 1788, "D")
        @t.add_result(2, 1796, 1804, "W")
        @t.add_result(2, 1797, 1739, "W")
        @t.add_result(2, 1798, 1769, "L")
        @t.add_result(2, 1799, 1758, "W")
        @t.add_result(2, 1800, 1828, "L")
        @t.add_result(2, 1801, 1749, "L")
        @t.add_result(2, 1802, 1735, "W")
        @t.add_result(2, 1803, 1773, "W")
        @t.add_result(2, 1804, 1796, "L")
        @t.add_result(2, 1805, 1731, "L")
        @t.add_result(2, 1806, 1767, "L")
        @t.add_result(2, 1807, 1737, "W")
        @t.add_result(2, 1808, 1786, "W")
        @t.add_result(2, 1809, 1732, "W")
        @t.add_result(2, 1810, 1733, "D")
        @t.add_result(2, 1811, 1759, "W")
        @t.add_result(2, 1812, 1745, "L")
        @t.add_result(2, 1813, 1743, "L")
        @t.add_result(2, 1814, 1775, "W")
        @t.add_result(2, 1815, 1783, "W")
        @t.add_result(2, 1816, 1782, "W")
        @t.add_result(2, 1817, 1738, "W")
        @t.add_result(2, 1818, 1819, "L")
        @t.add_result(2, 1819, 1818, "W")
        @t.add_result(2, 1820, 1784, "L")
        @t.add_result(2, 1821, 1746, "L")
        @t.add_result(2, 1822, 1761, "W")
        @t.add_result(2, 1823, 1736, "L")
        @t.add_result(2, 1824, 1740, "L")
        @t.add_result(2, 1825, 1751, "W")
        @t.add_result(2, 1826, 1756, "D")
        @t.add_result(2, 1827, 1747, "L")
        @t.add_result(2, 1828, 1800, "W")
        @t.add_result(2, 1829, 1763, "W")
        @t.add_result(2, 1830, 1734, "D")
        @t.add_result(3, 1730, 1814, "W")
        @t.add_result(3, 1731, 1815, "L")
        @t.add_result(3, 1732, 1825, "L")
        @t.add_result(3, 1733, 1783, "W")
        @t.add_result(3, 1734, 1828, "L")
        @t.add_result(3, 1735, 1803, "W")
        @t.add_result(3, 1736, 1778, "L")
        @t.add_result(3, 1737, 1790, "W")
        @t.add_result(3, 1738, 1761, "W")
        @t.add_result(3, 1739, 1762, "W")
        @t.add_result(3, 1740, 1800, "L")
        @t.add_result(3, 1741, 1757, "W")
        @t.add_result(3, 1742, 1775, "L")
        @t.add_result(3, 1743, 1812, "L")
        @t.add_result(3, 1744, 1749, "W")
        @t.add_result(3, 1745, 1816, "D")
        @t.add_result(3, 1746, 1774, "W")
        @t.add_result(3, 1747, 1806, "L")
        @t.add_result(3, 1748, 1802, "L")
        @t.add_result(3, 1749, 1744, "L")
        @t.add_result(3, 1750, 1787, "L")
        @t.add_result(3, 1751, 1768, "D")
        @t.add_result(3, 1752, 1766, "L")
        @t.add_result(3, 1753, 1773, "L")
        @t.add_result(3, 1754, 1813, "W")
        @t.add_result(3, 1755, 1760, "W")
        @t.add_result(3, 1756, 1823, "W")
        @t.add_result(3, 1757, 1741, "L")
        @t.add_result(3, 1758, 1824, "L")
        @t.add_result(3, 1759, 1821, "L")
        @t.add_result(3, 1760, 1755, "L")
        @t.add_result(3, 1761, 1738, "L")
        @t.add_result(3, 1762, 1739, "L")
        @t.add_result(3, 1764, 1810, "W")
        @t.add_result(3, 1765, 1826, "L")
        @t.add_result(3, 1766, 1752, "W")
        @t.add_result(3, 1767, 1784, "W")
        @t.add_result(3, 1768, 1751, "D")
        @t.add_result(3, 1769, 1781, "L")
        @t.add_result(3, 1770, 1811, "D")
        @t.add_result(3, 1771, 1777, "L")
        @t.add_result(3, 1772, 1819, "L")
        @t.add_result(3, 1773, 1753, "W")
        @t.add_result(3, 1774, 1746, "L")
        @t.add_result(3, 1775, 1742, "W")
        @t.add_result(3, 1776, 1820, "L")
        @t.add_result(3, 1777, 1771, "W")
        @t.add_result(3, 1778, 1736, "W")
        @t.add_result(3, 1779, 1805, "L")
        @t.add_result(3, 1780, 1795, "L")
        @t.add_result(3, 1781, 1769, "W")
        @t.add_result(3, 1782, 1822, "L")
        @t.add_result(3, 1783, 1733, "L")
        @t.add_result(3, 1784, 1767, "L")
        @t.add_result(3, 1785, 1798, "W")
        @t.add_result(3, 1786, 1801, "W")
        @t.add_result(3, 1787, 1750, "W")
        @t.add_result(3, 1788, 1830, "W")
        @t.add_result(3, 1789, 1797, "L")
        @t.add_result(3, 1790, 1737, "L")
        @t.add_result(3, 1791, 1794, "D")
        @t.add_result(3, 1792, 1804, "L")
        @t.add_result(3, 1793, 1829, "W")
        @t.add_result(3, 1794, 1791, "D")
        @t.add_result(3, 1795, 1780, "W")
        @t.add_result(3, 1796, 1809, "W")
        @t.add_result(3, 1797, 1789, "W")
        @t.add_result(3, 1798, 1785, "L")
        @t.add_result(3, 1799, 1831, "W")
        @t.add_result(3, 1800, 1740, "W")
        @t.add_result(3, 1801, 1786, "L")
        @t.add_result(3, 1802, 1748, "W")
        @t.add_result(3, 1803, 1735, "L")
        @t.add_result(3, 1804, 1792, "W")
        @t.add_result(3, 1805, 1779, "W")
        @t.add_result(3, 1806, 1747, "W")
        @t.add_result(3, 1807, 1808, "L")
        @t.add_result(3, 1808, 1807, "W")
        @t.add_result(3, 1809, 1796, "L")
        @t.add_result(3, 1810, 1764, "L")
        @t.add_result(3, 1811, 1770, "D")
        @t.add_result(3, 1812, 1743, "W")
        @t.add_result(3, 1813, 1754, "L")
        @t.add_result(3, 1814, 1730, "L")
        @t.add_result(3, 1815, 1731, "W")
        @t.add_result(3, 1816, 1745, "D")
        @t.add_result(3, 1817, 1818, "L")
        @t.add_result(3, 1818, 1817, "W")
        @t.add_result(3, 1819, 1772, "W")
        @t.add_result(3, 1820, 1776, "W")
        @t.add_result(3, 1821, 1759, "W")
        @t.add_result(3, 1822, 1782, "W")
        @t.add_result(3, 1823, 1756, "L")
        @t.add_result(3, 1824, 1758, "W")
        @t.add_result(3, 1825, 1732, "W")
        @t.add_result(3, 1826, 1765, "W")
        @t.add_result(3, 1828, 1734, "W")
        @t.add_result(3, 1829, 1793, "L")
        @t.add_result(3, 1830, 1788, "L")
        @t.add_result(3, 1831, 1799, "L")
        @t.add_result(4, 1730, 1795, "D")
        @t.add_result(4, 1731, 1764, "W")
        @t.add_result(4, 1732, 1752, "W")
        @t.add_result(4, 1733, 1734, "L")
        @t.add_result(4, 1734, 1733, "W")
        @t.add_result(4, 1735, 1785, "W")
        @t.add_result(4, 1736, 1826, "L")
        @t.add_result(4, 1737, 1822, "L")
        @t.add_result(4, 1738, 1824, "W")
        @t.add_result(4, 1739, 1831, "L")
        @t.add_result(4, 1740, 1780, "L")
        @t.add_result(4, 1741, 1799, "D")
        @t.add_result(4, 1742, 1783, "L")
        @t.add_result(4, 1743, 1755, "L")
        @t.add_result(4, 1744, 1819, "D")
        @t.add_result(4, 1745, 1815, "W")
        @t.add_result(4, 1746, 1749, "W")
        @t.add_result(4, 1747, 1798, "L")
        @t.add_result(4, 1748, 1786, "W")
        @t.add_result(4, 1749, 1746, "L")
        @t.add_result(4, 1750, 1775, "L")
        @t.add_result(4, 1751, 1827, "W")
        @t.add_result(4, 1752, 1732, "L")
        @t.add_result(4, 1753, 1810, "L")
        @t.add_result(4, 1754, 1776, "W")
        @t.add_result(4, 1755, 1743, "W")
        @t.add_result(4, 1756, 1811, "L")
        @t.add_result(4, 1757, 1821, "D")
        @t.add_result(4, 1758, 1761, "W")
        @t.add_result(4, 1759, 1762, "L")
        @t.add_result(4, 1760, 1813, "L")
        @t.add_result(4, 1761, 1758, "L")
        @t.add_result(4, 1762, 1759, "W")
        @t.add_result(4, 1763, 1768, "D")
        @t.add_result(4, 1764, 1731, "L")
        @t.add_result(4, 1765, 1789, "L")
        @t.add_result(4, 1766, 1809, "L")
        @t.add_result(4, 1767, 1796, "W")
        @t.add_result(4, 1768, 1763, "D")
        @t.add_result(4, 1769, 1800, "L")
        @t.add_result(4, 1770, 1830, "L")
        @t.add_result(4, 1771, 1792, "L")
        @t.add_result(4, 1772, 1820, "L")
        @t.add_result(4, 1773, 1774, "W")
        @t.add_result(4, 1774, 1773, "L")
        @t.add_result(4, 1775, 1750, "W")
        @t.add_result(4, 1776, 1754, "L")
        @t.add_result(4, 1777, 1804, "D")
        @t.add_result(4, 1778, 1791, "W")
        @t.add_result(4, 1779, 1823, "W")
        @t.add_result(4, 1780, 1740, "W")
        @t.add_result(4, 1781, 1828, "L")
        @t.add_result(4, 1782, 1790, "L")
        @t.add_result(4, 1783, 1742, "W")
        @t.add_result(4, 1784, 1797, "L")
        @t.add_result(4, 1785, 1735, "L")
        @t.add_result(4, 1786, 1748, "L")
        @t.add_result(4, 1787, 1794, "L")
        @t.add_result(4, 1788, 1816, "L")
        @t.add_result(4, 1789, 1765, "W")
        @t.add_result(4, 1790, 1782, "W")
        @t.add_result(4, 1791, 1778, "L")
        @t.add_result(4, 1792, 1771, "W")
        @t.add_result(4, 1793, 1807, "W")
        @t.add_result(4, 1794, 1787, "W")
        @t.add_result(4, 1795, 1730, "D")
        @t.add_result(4, 1796, 1767, "L")
        @t.add_result(4, 1797, 1784, "W")
        @t.add_result(4, 1798, 1747, "W")
        @t.add_result(4, 1799, 1741, "D")
        @t.add_result(4, 1800, 1769, "W")
        @t.add_result(4, 1801, 1829, "W")
        @t.add_result(4, 1802, 1808, "D")
        @t.add_result(4, 1803, 1817, "L")
        @t.add_result(4, 1804, 1777, "D")
        @t.add_result(4, 1805, 1814, "L")
        @t.add_result(4, 1806, 1825, "W")
        @t.add_result(4, 1807, 1793, "L")
        @t.add_result(4, 1808, 1802, "D")
        @t.add_result(4, 1809, 1766, "W")
        @t.add_result(4, 1810, 1753, "W")
        @t.add_result(4, 1811, 1756, "W")
        @t.add_result(4, 1812, 1818, "L")
        @t.add_result(4, 1813, 1760, "W")
        @t.add_result(4, 1814, 1805, "W")
        @t.add_result(4, 1815, 1745, "L")
        @t.add_result(4, 1816, 1788, "W")
        @t.add_result(4, 1817, 1803, "W")
        @t.add_result(4, 1818, 1812, "W")
        @t.add_result(4, 1819, 1744, "D")
        @t.add_result(4, 1820, 1772, "W")
        @t.add_result(4, 1821, 1757, "D")
        @t.add_result(4, 1822, 1737, "W")
        @t.add_result(4, 1823, 1779, "L")
        @t.add_result(4, 1824, 1738, "L")
        @t.add_result(4, 1825, 1806, "L")
        @t.add_result(4, 1826, 1736, "W")
        @t.add_result(4, 1827, 1751, "L")
        @t.add_result(4, 1828, 1781, "W")
        @t.add_result(4, 1829, 1801, "L")
        @t.add_result(4, 1830, 1770, "W")
        @t.add_result(4, 1831, 1739, "W")
        @t.add_result(5, 1730, 1806, "W")
        @t.add_result(5, 1731, 1741, "W")
        @t.add_result(5, 1732, 1831, "W")
        @t.add_result(5, 1733, 1756, "L")
        @t.add_result(5, 1734, 1811, "D")
        @t.add_result(5, 1735, 1797, "W")
        @t.add_result(5, 1736, 1810, "W")
        @t.add_result(5, 1737, 1785, "L")
        @t.add_result(5, 1738, 1798, "W")
        @t.add_result(5, 1739, 1771, "D")
        @t.add_result(5, 1740, 1782, "W")
        @t.add_result(5, 1741, 1731, "L")
        @t.add_result(5, 1742, 1823, "W")
        @t.add_result(5, 1743, 1824, "W")
        @t.add_result(5, 1744, 1808, "D")
        @t.add_result(5, 1745, 1794, "L")
        @t.add_result(5, 1746, 1788, "D")
        @t.add_result(5, 1747, 1813, "L")
        @t.add_result(5, 1748, 1818, "W")
        @t.add_result(5, 1749, 1817, "W")
        @t.add_result(5, 1750, 1801, "W")
        @t.add_result(5, 1751, 1821, "L")
        @t.add_result(5, 1752, 1776, "W")
        @t.add_result(5, 1753, 1761, "W")
        @t.add_result(5, 1754, 1784, "L")
        @t.add_result(5, 1755, 1790, "L")
        @t.add_result(5, 1756, 1733, "W")
        @t.add_result(5, 1757, 1805, "L")
        @t.add_result(5, 1758, 1829, "L")
        @t.add_result(5, 1759, 1760, "W")
        @t.add_result(5, 1760, 1759, "L")
        @t.add_result(5, 1761, 1753, "L")
        @t.add_result(5, 1762, 1765, "D")
        @t.add_result(5, 1764, 1789, "W")
        @t.add_result(5, 1765, 1762, "D")
        @t.add_result(5, 1766, 1825, "W")
        @t.add_result(5, 1767, 1828, "W")
        @t.add_result(5, 1768, 1803, "L")
        @t.add_result(5, 1769, 1772, "L")
        @t.add_result(5, 1770, 1774, "D")
        @t.add_result(5, 1771, 1739, "D")
        @t.add_result(5, 1772, 1769, "W")
        @t.add_result(5, 1773, 1786, "D")
        @t.add_result(5, 1774, 1770, "D")
        @t.add_result(5, 1775, 1777, "W")
        @t.add_result(5, 1776, 1752, "L")
        @t.add_result(5, 1777, 1775, "L")
        @t.add_result(5, 1778, 1816, "W")
        @t.add_result(5, 1779, 1783, "W")
        @t.add_result(5, 1780, 1807, "W")
        @t.add_result(5, 1781, 1822, "L")
        @t.add_result(5, 1782, 1740, "L")
        @t.add_result(5, 1783, 1779, "L")
        @t.add_result(5, 1784, 1754, "W")
        @t.add_result(5, 1785, 1737, "W")
        @t.add_result(5, 1786, 1773, "D")
        @t.add_result(5, 1787, 1826, "W")
        @t.add_result(5, 1788, 1746, "D")
        @t.add_result(5, 1789, 1764, "L")
        @t.add_result(5, 1790, 1755, "W")
        @t.add_result(5, 1791, 1830, "L")
        @t.add_result(5, 1792, 1812, "L")
        @t.add_result(5, 1793, 1796, "W")
        @t.add_result(5, 1794, 1745, "W")
        @t.add_result(5, 1795, 1809, "L")
        @t.add_result(5, 1796, 1793, "L")
        @t.add_result(5, 1797, 1735, "L")
        @t.add_result(5, 1798, 1738, "L")
        @t.add_result(5, 1799, 1804, "D")
        @t.add_result(5, 1800, 1820, "W")
        @t.add_result(5, 1801, 1750, "L")
        @t.add_result(5, 1802, 1819, "L")
        @t.add_result(5, 1803, 1768, "W")
        @t.add_result(5, 1804, 1799, "D")
        @t.add_result(5, 1805, 1757, "W")
        @t.add_result(5, 1806, 1730, "L")
        @t.add_result(5, 1807, 1780, "L")
        @t.add_result(5, 1808, 1744, "D")
        @t.add_result(5, 1809, 1795, "W")
        @t.add_result(5, 1810, 1736, "L")
        @t.add_result(5, 1811, 1734, "D")
        @t.add_result(5, 1812, 1792, "W")
        @t.add_result(5, 1813, 1747, "W")
        @t.add_result(5, 1814, 1815, "W")
        @t.add_result(5, 1815, 1814, "L")
        @t.add_result(5, 1816, 1778, "L")
        @t.add_result(5, 1817, 1749, "L")
        @t.add_result(5, 1818, 1748, "L")
        @t.add_result(5, 1819, 1802, "W")
        @t.add_result(5, 1820, 1800, "L")
        @t.add_result(5, 1821, 1751, "W")
        @t.add_result(5, 1822, 1781, "W")
        @t.add_result(5, 1823, 1742, "L")
        @t.add_result(5, 1824, 1743, "L")
        @t.add_result(5, 1825, 1766, "L")
        @t.add_result(5, 1826, 1787, "L")
        @t.add_result(5, 1828, 1767, "L")
        @t.add_result(5, 1829, 1758, "W")
        @t.add_result(5, 1830, 1791, "W")
        @t.add_result(5, 1831, 1732, "L")
        @t.add_result(6, 1730, 1735, "L")
        @t.add_result(6, 1731, 1830, "W")
        @t.add_result(6, 1732, 1804, "D")
        @t.add_result(6, 1733, 1763, "W")
        @t.add_result(6, 1734, 1795, "L")
        @t.add_result(6, 1735, 1730, "W")
        @t.add_result(6, 1736, 1741, "L")
        @t.add_result(6, 1737, 1821, "D")
        @t.add_result(6, 1738, 1772, "L")
        @t.add_result(6, 1739, 1783, "W")
        @t.add_result(6, 1740, 1817, "L")
        @t.add_result(6, 1741, 1736, "W")
        @t.add_result(6, 1742, 1831, "D")
        @t.add_result(6, 1743, 1825, "L")
        @t.add_result(6, 1744, 1793, "W")
        @t.add_result(6, 1745, 1802, "L")
        @t.add_result(6, 1746, 1820, "W")
        @t.add_result(6, 1747, 1768, "W")
        @t.add_result(6, 1748, 1828, "W")
        @t.add_result(6, 1749, 1796, "D")
        @t.add_result(6, 1750, 1756, "W")
        @t.add_result(6, 1751, 1810, "L")
        @t.add_result(6, 1752, 1798, "L")
        @t.add_result(6, 1753, 1782, "L")
        @t.add_result(6, 1754, 1755, "L")
        @t.add_result(6, 1755, 1754, "W")
        @t.add_result(6, 1756, 1750, "L")
        @t.add_result(6, 1757, 1771, "L")
        @t.add_result(6, 1758, 1827, "W")
        @t.add_result(6, 1759, 1824, "W")
        @t.add_result(6, 1761, 1823, "L")
        @t.add_result(6, 1762, 1774, "L")
        @t.add_result(6, 1763, 1733, "L")
        @t.add_result(6, 1764, 1791, "W")
        @t.add_result(6, 1765, 1776, "W")
        @t.add_result(6, 1766, 1788, "D")
        @t.add_result(6, 1767, 1778, "W")
        @t.add_result(6, 1768, 1747, "L")
        @t.add_result(6, 1769, 1792, "L")
        @t.add_result(6, 1770, 1807, "W")
        @t.add_result(6, 1771, 1757, "W")
        @t.add_result(6, 1772, 1738, "W")
        @t.add_result(6, 1773, 1826, "L")
        @t.add_result(6, 1774, 1762, "W")
        @t.add_result(6, 1775, 1816, "L")
        @t.add_result(6, 1776, 1765, "L")
        @t.add_result(6, 1777, 1797, "L")
        @t.add_result(6, 1778, 1767, "L")
        @t.add_result(6, 1780, 1811, "L")
        @t.add_result(6, 1781, 1818, "W")
        @t.add_result(6, 1782, 1753, "W")
        @t.add_result(6, 1783, 1739, "L")
        @t.add_result(6, 1784, 1790, "D")
        @t.add_result(6, 1785, 1806, "W")
        @t.add_result(6, 1786, 1805, "W")
        @t.add_result(6, 1787, 1814, "L")
        @t.add_result(6, 1788, 1766, "D")
        @t.add_result(6, 1790, 1784, "D")
        @t.add_result(6, 1791, 1764, "L")
        @t.add_result(6, 1792, 1769, "W")
        @t.add_result(6, 1793, 1744, "L")
        @t.add_result(6, 1794, 1819, "D")
        @t.add_result(6, 1795, 1734, "W")
        @t.add_result(6, 1796, 1749, "D")
        @t.add_result(6, 1797, 1777, "W")
        @t.add_result(6, 1798, 1752, "W")
        @t.add_result(6, 1799, 1812, "D")
        @t.add_result(6, 1800, 1809, "W")
        @t.add_result(6, 1801, 1803, "L")
        @t.add_result(6, 1802, 1745, "W")
        @t.add_result(6, 1803, 1801, "W")
        @t.add_result(6, 1804, 1732, "D")
        @t.add_result(6, 1805, 1786, "L")
        @t.add_result(6, 1806, 1785, "L")
        @t.add_result(6, 1807, 1770, "L")
        @t.add_result(6, 1808, 1822, "W")
        @t.add_result(6, 1809, 1800, "L")
        @t.add_result(6, 1810, 1751, "W")
        @t.add_result(6, 1811, 1780, "W")
        @t.add_result(6, 1812, 1799, "D")
        @t.add_result(6, 1813, 1829, "W")
        @t.add_result(6, 1814, 1787, "W")
        @t.add_result(6, 1816, 1775, "W")
        @t.add_result(6, 1817, 1740, "W")
        @t.add_result(6, 1818, 1781, "L")
        @t.add_result(6, 1819, 1794, "D")
        @t.add_result(6, 1820, 1746, "L")
        @t.add_result(6, 1821, 1737, "D")
        @t.add_result(6, 1822, 1808, "L")
        @t.add_result(6, 1823, 1761, "W")
        @t.add_result(6, 1824, 1759, "L")
        @t.add_result(6, 1825, 1743, "W")
        @t.add_result(6, 1826, 1773, "W")
        @t.add_result(6, 1827, 1758, "L")
        @t.add_result(6, 1828, 1748, "L")
        @t.add_result(6, 1829, 1813, "L")
        @t.add_result(6, 1830, 1731, "L")
        @t.add_result(6, 1831, 1742, "D")
      end

      it "should be setup properly" do
        @p.desc.should  == "Sasha-Ettore Faleschini"
        @o1.desc.should == "John P. Dunne"
        @o2.desc.should == "Jack Fitzgerald"
        @o3.desc.should == "Mikolaj Glegolski"
        @o4.desc.should == "Daniel Boland"
        @o5.desc.should == "Noel Keating"
        @o6.desc.should == "Cathal Minnock"

        @p.type.should  == :unrated
        @o1.type.should == :rated
        @o2.type.should == :rated
        @o3.type.should == :rated
        @o4.type.should == :rated
        @o5.type.should == :rated
        @o6.type.should == :rated

        @o1.rating.should == 946
        @o2.rating.should == 913
        @o3.rating.should == 841
        @o4.rating.should == 793
        @o5.rating.should == 667
        @o6.rating.should == 917

        @t.iterations1.should be_nil
        @t.iterations2.should be_nil
      end

      it "should produce inconsistent results with original algorithm" do
        @t.rate!

        @p.new_rating.should == @p.performance

        @o1.bonus.should == 16
        @o2.bonus.should == 0
        @o3.bonus.should == 0
        @o4.bonus.should == 0
        @o5.bonus.should == 0
        @o6.bonus.should == 0

        ratings = [@o1, @o2, @o3, @o4, @o5, @o6].map { |o| o.bonus == 0 ? o.rating : o.new_rating }

        performance = ratings.inject(0.0){ |m,r| m = m + r } / 6.0 - 400.0 / 3.0
        performance.should_not be_within(0.5).of(@p.new_rating)

        @t.iterations1.should be > 1
        @t.iterations2.should == 1
      end

      it "should produce inconsistent results with version 1 algorithm" do
        @t.rate!(version: 1)

        @p.new_rating.should == @p.performance

        @o1.bonus.should == 16
        @o2.bonus.should == 0
        @o3.bonus.should == 0
        @o4.bonus.should == 0
        @o5.bonus.should == 0
        @o6.bonus.should == 0

        ratings = [@o1, @o2, @o3, @o4, @o5, @o6].map { |o| o.bonus == 0 ? o.rating : o.new_rating }

        performance = ratings.inject(0.0){ |m,r| m = m + r } / 6.0 - 400.0 / 3.0
        performance.should_not be_within(0.5).of(@p.new_rating)

        @t.iterations1.should be > 1
        @t.iterations2.should be > 1
      end

      it "should produce consistent results with version 2 algorithm" do
        @t.rate!(version: 2)

        @o1.bonus.should == 0  # no bonus this time because it comes from 2nd phase
        @o2.bonus.should == 0
        @o3.bonus.should == 0
        @o4.bonus.should == 0
        @o5.bonus.should == 0
        @o6.bonus.should == 0

        ratings = [@o1, @o2, @o3, @o4, @o5, @o6].map { |o| o.bonus == 0 ? o.rating : o.new_rating }

        performance = ratings.inject(0.0){ |m,r| m = m + r } / 6.0 - 400.0 / 3.0
        performance.should be_within(0.5).of(@p.new_rating)

        @t.iterations1.should be > 1
        @t.iterations2.should be > 1
      end

      it "should produce consistent results with version 3 algorithm" do
        @t.rate!(version: 3)

        @o1.bonus.should == 0  # no bonus this time because it comes from 2nd phase
        @o2.bonus.should == 0
        @o3.bonus.should == 0
        @o4.bonus.should == 0
        @o5.bonus.should == 0
        @o6.bonus.should == 0

        ratings = [@o1, @o2, @o3, @o4, @o5, @o6].map { |o| o.bonus == 0 ? o.rating : o.new_rating }

        performance = ratings.inject(0.0){ |m,r| m = m + r } / 6.0 - 400.0 / 3.0
        performance.should be_within(0.5).of(@p.new_rating)

        @t.iterations1.should be > 1
        @t.iterations2.should be > 1
      end
    end

    context "#rate - Deirdre Turner in the Limerick U1400 2012" do
      before(:each) do
        @t = ICU::RatedTournament.new(desc: "Limerick U1400 2012")

        # Add the players of most interest (Deirdre Turner and her opponents).
        @p  = @t.add_player(6697, desc: "Deirdre Turner")
        @o1 = @t.add_player(6678, desc: "John P. Dunne",      rating:  980, kfactor: 40)
        @o2 = @t.add_player(6694, desc: "Jordan O'Sullivan")
        @o3 = @t.add_player(6681, desc: "Ruairi Freeman",     rating:  537, kfactor: 40)
        @o4 = @t.add_player(6676, desc: "Joe Cronin",         rating:  682, kfactor: 32)
        @o5 = @t.add_player(6675, desc: "Jeffrey Alfred",     rating: 1320, kfactor: 40)
        @o6 = @t.add_player(6687, desc: "Roisin MacNamee",    rating:  460, games:    7)

        # Add all the other players.
        @t.add_player(6679, desc: "Thomas Senior Dunne",      rating:  876, kfactor: 32)
        @t.add_player(6682, desc: "John Hensey",              rating: 1347, kfactor: 24)
        @t.add_player(6683, desc: "Noel Keating",             rating:  622, kfactor: 32)
        @t.add_player(6684, desc: "Thomas Keating",           rating:  886, kfactor: 40)
        @t.add_player(6686, desc: "Nora MacNamee",            rating:  508, kfactor: 40)
        @t.add_player(6690, desc: "Robbie Meaney",            rating: 1020, kfactor: 40)
        @t.add_player(6691, desc: "Stephen Meaney",           rating:  979, kfactor: 40)
        @t.add_player(6692, desc: "Jessica Mulqueen-Danaher", rating:  435, kfactor: 40)
        @t.add_player(6693, desc: "Michael Joseph O'Connell", rating:  965, kfactor: 32)
        @t.add_player(6677, desc: "Adam Dean",                rating:  652, games:    6)
        @t.add_player(6680, desc: "Geordan Freeman",          rating:  344, games:   10)
        @t.add_player(6685, desc: "Eamon MacNamee")
        @t.add_player(6688, desc: "Pippa Madigan")
        @t.add_player(6689, desc: "John McNamara")
        @t.add_player(6695, desc: "Grigory Ramendik")
        @t.add_player(6696, desc: "Mark David Tonita")
        @t.add_player(6698, desc: "Eoghan Turner")

        # Deirdre's results.
        @t.add_result(1, 6697, 6678, "L")
        @t.add_result(2, 6697, 6694, "W")
        @t.add_result(3, 6697, 6681, "W")
        @t.add_result(4, 6697, 6676, "L")
        @t.add_result(5, 6697, 6675, "L")
        @t.add_result(6, 6697, 6687, "W")

        # Other results.
        @t.add_result(1, 6689, 6676, "L")
        @t.add_result(1, 6693, 6677, "L")
        @t.add_result(1, 6695, 6679, "L")
        @t.add_result(1, 6694, 6681, "L")
        @t.add_result(1, 6692, 6682, "L")
        @t.add_result(1, 6688, 6683, "L")
        @t.add_result(1, 6698, 6684, "D")
        @t.add_result(1, 6691, 6685, "W")
        @t.add_result(1, 6696, 6686, "L")
        @t.add_result(1, 6690, 6687, "W")
        @t.add_result(2, 6684, 6675, "D")
        @t.add_result(2, 6682, 6676, "W")
        @t.add_result(2, 6698, 6677, "L")
        @t.add_result(2, 6683, 6678, "L")
        @t.add_result(2, 6686, 6679, "L")
        @t.add_result(2, 6690, 6680, "W")
        @t.add_result(2, 6691, 6681, "W")
        @t.add_result(2, 6693, 6685, "W")
        @t.add_result(2, 6695, 6687, "L")
        @t.add_result(2, 6692, 6689, "W")
        @t.add_result(3, 6678, 6675, "W")
        @t.add_result(3, 6687, 6676, "L")
        @t.add_result(3, 6682, 6677, "W")
        @t.add_result(3, 6696, 6680, "D")
        @t.add_result(3, 6686, 6683, "L")
        @t.add_result(3, 6693, 6684, "D")
        @t.add_result(3, 6698, 6685, "W")
        @t.add_result(3, 6692, 6688, "W")
        @t.add_result(3, 6695, 6689, "L")
        @t.add_result(3, 6691, 6690, "W")
        @t.add_result(4, 6687, 6675, "L")
        @t.add_result(4, 6683, 6677, "W")
        @t.add_result(4, 6682, 6678, "D")
        @t.add_result(4, 6691, 6679, "W")
        @t.add_result(4, 6684, 6680, "W")
        @t.add_result(4, 6693, 6681, "L")
        @t.add_result(4, 6695, 6685, "W")
        @t.add_result(4, 6694, 6686, "L")
        @t.add_result(4, 6692, 6690, "L")
        @t.add_result(4, 6698, 6696, "W")
        @t.add_result(5, 6683, 6676, "W")
        @t.add_result(5, 6692, 6677, "L")
        @t.add_result(5, 6691, 6678, "W")
        @t.add_result(5, 6698, 6679, "D")
        @t.add_result(5, 6687, 6680, "W")
        @t.add_result(5, 6689, 6681, "L")
        @t.add_result(5, 6690, 6682, "L")
        @t.add_result(5, 6686, 6684, "L")
        @t.add_result(5, 6696, 6693, "L")
        @t.add_result(5, 6695, 6694, "D")
        @t.add_result(6, 6677, 6675, "D")
        @t.add_result(6, 6698, 6676, "W")
        @t.add_result(6, 6679, 6678, "L")
        @t.add_result(6, 6694, 6680, "L")
        @t.add_result(6, 6690, 6681, "W")
        @t.add_result(6, 6691, 6682, "L")
        @t.add_result(6, 6684, 6683, "L")
        @t.add_result(6, 6696, 6685, "W")
        @t.add_result(6, 6689, 6686, "L")
        @t.add_result(6, 6693, 6692, "W")
      end

      it "should be setup properly" do
        @p.desc.should  == "Deirdre Turner"
        @o1.desc.should == "John P. Dunne"
        @o2.desc.should == "Jordan O'Sullivan"
        @o3.desc.should == "Ruairi Freeman"
        @o4.desc.should == "Joe Cronin"
        @o5.desc.should == "Jeffrey Alfred"
        @o6.desc.should == "Roisin MacNamee"

        @p.type.should  == :unrated
        @o1.type.should == :rated
        @o2.type.should == :unrated
        @o3.type.should == :rated
        @o4.type.should == :rated
        @o5.type.should == :rated
        @o6.type.should == :provisional

        @o1.rating.should == 980
        @o2.should_not respond_to(:rating)
        @o3.rating.should == 537
        @o4.rating.should == 682
        @o5.rating.should == 1320
        @o6.rating.should == 460

        @t.iterations1.should be_nil
        @t.iterations2.should be_nil
      end

      it "should produce consistent results with version 2 algorithm" do
        @t.rate!(version: 2)

        @p.new_rating.should == @p.performance

        @o1.bonus.should == 23
        @o3.bonus.should == 0
        @o4.bonus.should == 0
        @o5.bonus.should == 0

        ratings = [@o1, @o2, @o3, @o4, @o5, @o6].map { |o| o.new_rating(:opponent) }

        performance = ratings.inject(0.0){ |m,r| m = m + r } / 6.0
        performance.should be_within(0.1).of(@p.new_rating)

        @t.iterations1.should be > 1
        @t.iterations2.should be > 1
      end
    end
  end
end
