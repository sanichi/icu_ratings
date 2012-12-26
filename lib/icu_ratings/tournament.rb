# encoding: utf-8

module ICU
  #
  # == Creating Tournaments
  #
  # ICU::RatedTournament objects are created directly.
  #
  #   t = ICU::RatedTournament.new
  #
  # They have some optional parameters which can be set via the constructor or by calling
  # the same-named setter methods. One is called _desc_ (short for description) the value
  # of which can be any object but will, if utilized, typically be the name of the
  # tournament as a string.
  #
  #   t = ICU::RatedTournament.new(:desc => "Irish Championships 2010")
  #   puts t.desc                         # "Irish Championships 2010"
  #
  # Another optional parameter is _start_ for the start date. A Date object or a string that can be
  # parsed as a string can be used to set it. The European convention is preferred for dates like
  # "03/06/2013" (3rd of June, not 6th of March). Attempting to set an invalid date will raise an
  # exception.
  #
  #   t = ICU::RatedTournament.new(:start => "01/07/2010")
  #   puts t.start.class                  # Date
  #   puts t.start.to_s                   # "2010-07-01"
  #
  # Also, there is the option _no_bonuses_. Bonuses are a feature of the ICU rating system. If you are
  # rating a non-ICU tournament (such as a FIDE tournament) where bonues are not awarded use this option.
  #
  #   t = ICU::RatedTournament.new(:desc => 'Linares', :start => "07/02/2009", :no_bonuses => true)
  #
  # Note, however, that the ICU system also has its own unique way of treating provisional, unrated and
  # foreign players, so the only FIDE tournaments that can be rated using this software are those that
  # consist solely of rated players.
  #
  # == Rating Tournaments
  #
  # To rate a tournament, first add the players (see ICU::RatedPlayer for details):
  #
  #   t.add_player(1, :rating => 2534, :kfactor => 16)
  #   # ...
  #
  # Then add the results (see ICU::RatedResult for details):
  #
  #   t.add_result(1, 1, 2, 'W')
  #   # ...
  #
  # Then rate the tournament by calling the <em>rate!</em> method:
  #
  #   t.rate!
  #
  # Now the results of the rating calculations can be retrieved from the players in the tournement
  # or their results. For example, player 1's new rating would be:
  #
  #   t.player(1).new_rating
  #
  # See ICU::RatedPlayer and ICU::RatedResult for more details.
  #
  # The <em>rate!</em> method takes an optional <em>version</em> argument to control the precise algorithm, for example:
  #
  #   t.rate!(version: 2)
  #
  # Without a version number or with version <em>0</em>, the original pre-2012 algorithm is used. However, some improvements
  # have since been found (see http://ratings.icu.ie/articles/18 for more details) and currently
  # the recommended version to use is <b>2</b>.
  #
  # == Error Handling
  #
  # Some of the above methods have the potential to raise RuntimeError exceptions.
  # In the case of _add_player_ and _add_result_, the use of invalid arguments would
  # cause such an error. Theoretically, the <em>rate!</em> method could also throw
  # an exception if the iterative algorithm it uses to estimate performance ratings
  # of unrated players failed to converge. However an instance of non-convergence
  # has yet to be observed in practice.
  #
  # Since exception throwing is how errors are signalled, you should arrange
  # for them to be caught and handled in some suitable place in your code.
  #
  class RatedTournament
    attr_accessor :desc
    attr_reader :start, :no_bonuses, :iterations1, :iterations2

    # Add a new player to the tournament. Returns the instance of ICU::RatedPlayer created.
    # See ICU::RatedPlayer for details.
    def add_player(num, args={})
      raise "player with number #{num} already exists" if @player[num]
      args[:kfactor] = ICU::RatedPlayer.kfactor(args[:kfactor].merge({ :start => start, :rating => args[:rating] })) if args[:kfactor].is_a?(Hash)
      @player[num] = ICU::RatedPlayer.new(num, args)
    end

    # Add a new result to the tournament. Two instances of ICU::RatedResult are
    # created. One is added to the first player and the other to the second player.
    # The method returns _nil_. See ICU::RatedResult for details.
    def add_result(round, player, opponent, score)
      n1 = player.is_a?(ICU::RatedPlayer) ? player.num : player.to_i
      n2 = opponent.is_a?(ICU::RatedPlayer) ? opponent.num : opponent.to_i
      p1 = @player[n1] || raise("no such player number (#{n1})")
      p2 = @player[n2] || raise("no such player number (#{n2})")
      r1 = ICU::RatedResult.new(round, p2, score)
      r2 = ICU::RatedResult.new(round, p1, r1.opponents_score)
      p1.add_result(r1)
      p2.add_result(r2)
      nil
    end

    # Rate the tournament. Called after all players and results have been added.
    def rate!(opt={})
      # The original algorithm (version 0).
      max_iterations  = [30, 1]
      phase_2_bonuses = true
      update_bonuses  = false
      threshold       = 0.5

      # New versions of the algorithm.
      version = opt[:version].to_i
      if version >= 1
        # See http://ratings.icu.ie/articles/18 (Part 1)
        max_iterations[1] = 30
      end
      if version >= 2
        # See http://ratings.icu.ie/articles/18 (Part 2)
        phase_2_bonuses = false
        update_bonuses  = true
        threshold       = 0.1
      end

      # Phase 1.
      players.each { |p| p.init }
      @iterations1 = performance_ratings(max_iterations[0], threshold)
      players.each { |p| p.rate! }

      # Phase 2.
      if !no_bonuses && calculate_bonuses > 0
        players.each { |p| p.rate!(update_bonuses) }
        @iterations2 = performance_ratings(max_iterations[1], threshold)
        calculate_bonuses if phase_2_bonuses
      else
        @iterations2 = 0
      end
    end

    # Return an array of all players, in order of player number.
    def players
      @player.keys.sort.map{ |num| @player[num] }
    end

    # Return a player (ICU::RatedPlayer) given a player number (returns _nil_ if the number is invalid).
    def player(num)
      @player[num]
    end

    # Set the start date. Raises exception on error.
    def start=(date)
      @start = ICU::Util.parsedate!(date)
    end

    # Set whether there are no bonuses (false by default).
    def no_bonuses=(no_bonuses)
      @no_bonuses = no_bonuses ? true : false
    end

    private

    # Create a new, empty (no players, no results) tournament.
    def initialize(opt={})
      [:desc, :start, :no_bonuses].each { |atr| self.send("#{atr}=", opt[atr]) unless opt[atr].nil? }
      @player = Hash.new
    end

    # Calculate performance ratings either iteratively up to a maximum number.
    def performance_ratings(max, thresh)
      stable, count = false, 0
      while !stable && count < max
        @player.values.each { |p| p.estimate_performance }
        stable = @player.values.inject(true) { |ok, p| p.update_performance(thresh) && ok }
        count+= 1
      end
      raise "performance rating estimation did not converge" if max > 1 && !stable
      count
    end

    # Calculate bonuses for all players and return the number who got one.
    def calculate_bonuses
      @player.values.inject(0) { |t,p| t + (p.calculate_bonus ? 1 : 0) }
    end
  end
end
