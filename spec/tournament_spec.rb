# encoding: utf-8
require File.dirname(__FILE__) + '/spec_helper'

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

        @t.player(1).expected_score.should be_close(2.249, 0.001)
        @t.player(2).expected_score.should be_close(1.760, 0.001)
        @t.player(3).expected_score.should be_close(1.240, 0.001)
        @t.player(4).expected_score.should be_close(0.751, 0.001)

        @t.player(1).rating_change.should be_close(7.51,   0.01)
        @t.player(2).rating_change.should be_close(4.81,   0.01)
        @t.player(3).rating_change.should be_close(-7.21,  0.01)
        @t.player(4).rating_change.should be_close(-30.05, 0.01)

        @t.player(1).new_rating.should be_close(2207.5, 0.1)
        @t.player(2).new_rating.should be_close(2104.8, 0.1)
        @t.player(3).new_rating.should be_close(1992.8, 0.1)
        @t.player(4).new_rating.should be_close(1870.0, 0.1)
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
          p.expected_score.should be_close(expected_score, 0.001)
          p.new_rating.should be_close(new_rating, 0.5)
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
          p.performance.should_not be_close(ytd_performance, 0.5)
          p.performance.should be_close(tournament_performance, 0.5)
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
        @t.player(1).expected_score.should be_close(1.689, 0.001)
        @t.player(2).expected_score.should be_close(1.311, 0.001)
        @t.player(1).new_rating.should be_close(1378, 0.5)
        @t.player(2).new_rating.should be_close(1261, 0.5)
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
            p.rating_change.should == 0.0
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
        af.expected_score.should be_close(6.054, 0.001)
        af.new_rating.should be_close(2080, 0.5)

        pc.score.should == 4.0
        pc.expected_score.should be_close(3.685, 0.001)
        pc.new_rating.should be_close(1984, 0.5)
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
          p.expected_score.should be_close(expected_score, 0.01)
          p.new_rating.should be_close(new_rating, 0.5)
          p.results.inject(p.rating){ |t,r| t + r.rating_change }.should be_close(new_rating, 0.5)
        end
      end

      it "should agree with ICU database for provisionally rated players with results" do
        [
          [12,  0.59, 1157],
          [16,  0.07, 1023],
        ].each do |item|
          num, expected_score, new_rating = item
          p = @t.player(num)
          p.expected_score.should be_close(expected_score, 0.01)
          p.new_rating.should be_close(new_rating, 0.5)
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
          p.expected_score.should be_close(expected_score, 0.01)
          p.new_rating.should be_close(new_rating, 0.5)
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
          p.expected_score.should be_close(expected_score, 0.01)
          p.new_rating.should be_close(new_rating, 0.5)
          p.bonus.should == bonus
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
          p.expected_score.should be_close(expected_score, 0.01)
          p.performance.should be_close(performance, 0.5)
          if num == 1
            p.new_rating.should be_close(1836, 0.5)
            p.bonus.should == 71
          else
            p.new_rating.should == p.rating
          end
        end
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
          [1, 3.5, 3.84,  977, 1073,  0], # Austin
          [2, 4.0, 3.51, 1068, 1042,  0], # Kevin
          [3, 1.0, 1.05,  636,  636,  0], # Nikhil
          [4, 0.0, 0.78,  520,  537,  0], # Sean
          [5, 3.5, 1.74, 1026,  835, 45], # Michael
          [6, 3.0, 3.54,  907, 1010,  0], # Eoin
        ].each do |item|
          num, score, expected_score, performance, new_rating, bonus = item
          p = @t.player(num)
          p.score.should == score
          p.bonus.should == bonus
          p.performance.should be_close(performance, 0.5)
          p.expected_score.should be_close(expected_score, 0.01)
          p.new_rating.should be_close(new_rating, 0.5)
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
          [1, 4.0, 4.28, 1052, 1052,  0], # Fanjini
          [2, 3.5, 1.93,  920,  757, 35], # Guinan
          [3, 3.5, 2.29,  932,  798, 18], # Duffy
          [4, 1.0, 1.52,  588,  707,  0], # Cooke
          [5, 1.0, 1.40,  828,  828,  0], # Callaghan
          [6, 1.0, 0.91,  627,  627,  0], # Montenegro
          [7, 0.0, 0.78,  460,  635,  0], # Lowry-O'Reilly
        ]
      end

      it "should agree with ICU rating database" do
        @m.each do |item|
          num, score, expected_score, performance, new_rating, bonus = item
          p = @t.player(num)
          p.score.should == score
          p.bonus.should == bonus
          p.performance.should be_close(performance, num == 2 ? 0.6 : 0.5)
          p.expected_score.should be_close(expected_score, 0.01)
          p.new_rating.should be_close(new_rating, 0.5)
        end
      end

      it "should give the same results if rated twice" do
        @t.rate!
        @m.each do |item|
          num, score, expected_score, performance, new_rating, bonus = item
          p = @t.player(num)
          p.score.should == score
          p.bonus.should == bonus
          p.performance.should be_close(performance, num == 2 ? 0.6 : 0.5)
          p.expected_score.should be_close(expected_score, 0.01)
          p.new_rating.should be_close(new_rating, 0.5)
        end
      end

      it "should be completely different if bonuses are turned off" do
        @t.no_bonuses = true
        @t.rate!
        @m.each do |item|
          num, score, expected_score, performance, new_rating, bonus = item
          p = @t.player(num)
          p.score.should == score
          p.bonus.should == 0
          p.performance.should_not be_close(performance, 1.0)
          p.expected_score.should_not be_close(expected_score, 0.01)
          p.new_rating.should_not be_close(new_rating, 1.0)
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
          p.expected_score.should be_close(expected_score, 0.01)
          p.new_rating.should be_close(new_rating, 0.5)
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
  end
end