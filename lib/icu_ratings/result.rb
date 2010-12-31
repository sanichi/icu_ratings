# encoding: utf-8

module ICU
  #
  # == Adding Results to Tournaments
  #
  # You don't create results directly with a constructor, instead, you add them to a tournament
  # using the _add_result_ method, giving the round number, the player numbers and the score
  # of the first player relative to the second:
  #
  #   t = ICU::RatedTournament.new
  #   t.add_player(10)
  #   t.add_player(20)
  #   t.add_result(1, 10, 20, 'W')
  #
  # The above example expresses the result that in round 1 player 10 won against player 20. An exception is raised
  # if either of the two players does not already exist in the tournament, if either player already has a game
  # with another opponent in that round or if the two players already have a different result against each other
  # in that round. Note that the result is added to both players: in the above example a win in round 1 against
  # player 20 is added to player 10's results and a loss against player 10 in round 1 is added to player 20's results.
  # It's OK (but unnecessary) to add the same result again from the other player's prespective as long as
  # the score is consistent.
  #
  #   t.add_result(1, 20, 10, 'L')   # unnecessary (nothing would change) but would not cause an exception
  #   t.add_result(1, 20, 10, 'D')   # inconsistent result - would raise an exception
  #
  # == Specifying the Score
  #
  # The method _score_ will always return a Float value (either 0.0, 0.5 or 1.0).
  # When specifying a score using the _add_result_ of ICU::Tourmanent the same values
  # can be used as can other, equally valid alternatives:
  #
  # win:: "1", "1.0", "W", "w" (String), 1 (Fixnum), 1.0 (Float)
  # loss:: "0", "0.0", "L", "l" (String), 0 (Fixnum), 0.0 (Float)
  # draw:: "½", "D", "d" (String), 0.5 (Float)
  #
  # Strings padded with whitespace also work (e.g. "  1.0  " and "  W  ").
  #
  # == Specifying the Players
  #
  # As described above, one way to specify the two players is via player numbers. Equally possible is player objects:
  #
  #   t = ICU::RatedTournament.new
  #   p = t.add_player(10)
  #   q = t.add_plater(20)
  #   t.add_result(1, p, q, 'W')
  #
  # Or indeed (although this is unnecessary):
  #
  #   t = ICU::RatedTournament.new
  #   t.add_player(10)
  #   t.add_plater(20)
  #   t.add_result(1, t.player(10), t.player(20), 'W')
  #
  # A players cannot have a results against themselves:
  #
  #   t.add_player(2, 10, 10, 'D')   # exception!
  #
  # == Retrieving Results
  #
  # Results belong to players (ICU::RatedPlayer objects) and are stored in an array accessed by the method _results_.
  # Each result has a _round_ number, an _opponent_ object (also an ICU::RatedPlayer object) and a _score_ (1.0, 0.5 or 0.0):
  #
  #   p = t.player(10)
  #   p.results.size      # 1
  #   r = p.results[0]
  #   r.round             # 1
  #   r.opponent.num      # 20
  #   r.score             # 1.0 (Float)
  #
  # The _results_ method returns results in round order, irrespective of what order they were added in:
  #
  #   t = ICU::RatedTournament.new
  #   [0,1,2,3,4].each { |num| t.add_player(num) }
  #   [3,1].each { |rnd| t.add_result(rnd, 0, rnd, 'W') }
  #   [4,2].each { |rnd| t.add_result(rnd, 0, rnd, 'L') }
  #   t.player(0).results.map{ |r| r.round }.join(',')      # "1,2,3,4"
  #
  # == Unrated Results
  #
  # Results that are not for rating, such as byes, walkovers and defaults, should not be
  # added to the tournament. Instead, players can simply have no results for certain rounds.
  # Indeed, it's even valid for players not to have any results at all (although, in that
  # case, for those players, no new rating can be calculated from the tournament).
  #
  # == After the Tournament is Rated
  #
  # The main rating calculations are avaiable from player methods (see ICU::RatedPlayer)
  # but additional details are available via methods of each player's individual results:
  # _expected_score_, _rating_change_.
  #
  class RatedResult
    # The round number.
    def round
      @round
    end

    # The player's opponent (an instance of ICU::RatedPlayer).
    def opponent
      @opponent
    end

    # The player's score in this game (1.0, 0.5 or 0.0).
    def score
      @score
    end

    # After the tournament has been rated, this returns the expected score (between 0 and 1)
    # for the player based on the rating difference with the opponent scaled by 400.
    # The standard Elo formula is used: 1/(1 + 10^(diff/400)).
    def expected_score
      @expected_score
    end

    # After the tournament has been rated, returns the change in rating due to this particular
    # result. Only for rated players (returns _nil_ for other types of players). Computed from
    # the difference between actual and expected scores multiplied by the player's K-factor.
    # The sum of these changes is the overall rating change for rated players.
    def rating_change
      @rating_change
    end

    def rate!(player) # :nodoc:
      player_rating   = player.full_rating?   ? player.rating         : player.performance
      opponent_rating = opponent.full_rating? ? opponent.bonus_rating : opponent.performance
      if player_rating && opponent_rating
        @expected_score = 1 / (1 + 10 ** ((opponent_rating - player_rating) / 400.0))
        @rating_change  = (@score - @expected_score) * player.kfactor if player.type == :rated
      end
    end

    def ==(other) # :nodoc:
      return false unless other.round    == round
      return false unless other.opponent == opponent
      return false unless other.score    == score
      true
    end

    def opponents_score # :nodoc:
      1.0 - score
    end

    private

    def initialize(round, opponent, score) # :nodoc:
      self.round    = round
      self.opponent = opponent
      self.score    = score
    end

    def round=(round)
      @round = round.to_i
      raise "invalid round number (#{round})" if @round <= 0
    end

    def opponent=(opponent)
      raise "invalid opponent class (#{opponent.class})" unless opponent.is_a? ICU::RatedPlayer
      @opponent = opponent
    end

    def score=(score)
      @score = case score.to_s.strip
        when /^(1\.0|1|\+|W|w)$/ then 1.0
        when /^(0\.5|½|\=|D|d)$/ then 0.5
        when /^(0\.0|0|\-|L|l)$/ then 0.0
        else raise "invalid score (#{score})"
      end
    end
  end
end