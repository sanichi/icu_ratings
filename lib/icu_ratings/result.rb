module ICU

=begin rdoc

== Adding Results to Tournaments

You don't create results directly with a constructor, instead, you add them to a tournament
using the _add_result_ method, giving the round number, the player numbers and the score
of the first player relative to the second:

  t = ICU::RatedTournament.new
  t.add_player(10)
  t.add_player(20)
  t.add_result(1, 10, 20, 'W')

The above example expresses the result that in round 1 player 10 won against player 20. An exception is raised
if either of the two players does not already exist in the tournament, if either player already has a game
with another opponent in that round or if the two players already have a different result against each other
in that round. Note that the result is added to both players: in the above example a win in round 1 against
player 20 is added to player 10's results and a loss against player 10 in round 1 is added to player 20's results.
It's OK (but unnecessary) to add the same result again from the other player's prespective as long as
the score is consistent.

  t.add_result(1, 20, 10, 'L')   # unnecessary (nothing would change) but would not cause an exception
  t.add_result(1, 20, 10, 'D')   # inconsistent result - would raise an exception

Specifying the Score

The method _ICU::RatedResult#score_ will always return a Float value (either _0.0_, _0.5_ or _1.0_).
When specifying a score using the _ICU::Tourmanent#add_result_ the same values can be used but there
are also other, equivalent values that are equally valid:

* win: "1", "1.0", "W", "w" (String), _1_ (Fixnum), _1.0_ (Float)
* loss: "0", "0.0", "L", "l" (String), _0_ (Fixnum), _0.0_ (Float)
* draw: "½", "D", "d" (String), _0.5_ (Float)

Strings padded with whitespace also work (e.g. _"  1.0  "_ and _"  W  "_).

Specifying the Players

As described above, one way to specify the two players is via player numbers. Equally possible is player objects:

  t = ICU::RatedTournament.new
  p10 = t.add_player(10)
  p20 = t.add_plater(20)
  t.add_result(1, p10, p20, 'W')

Or indeed (although this is getting a bit contrived):

  t = ICU::RatedTournament.new
  t.add_player(10)
  t.add_plater(20)
  t.add_result(1, t.player(10), t.player(20), 'W')

A player cannot have a result against himself/herself:

  t.add_player(2, 10, 10, 'D')   # exception!

Retrieving Results

Results belong to players (ICU::RatedPlayer objects) and are stored in an array accessed by the method _results_.
Each result has a round number, an opponent object (also an ICU::RatedPlayer object) and a score (_1.0_, _0.5_ or _0.0_):

  p = t.player(10)
  p.results.size      # 1
  r = p.results[0]
  r.round             # 1
  r.opponent.num      # 20
  r.score             # 1.0 (Float)

The _ICU::RatedPlayer#results_ method returns results in round order, irrespective of what order they were added in:

  t = ICU::RatedTournament.new
  [0,1,2,3,4].each { |num| t.add_player(num) }
  [3,1].each { |rnd| t.add_result(rnd, 0, rnd, 'W') }
  [4,2].each { |rnd| t.add_result(rnd, 0, rnd, 'L') }
  t.player(0).results.map{ |r| r.round }.join(',')      # "1,2,3,4"

Unrateable Results

Results that are not for rating should not be added to the ICU::RatedTournament.
Obviously it would be impossible to add byes where there is no opponent, as the
_add_result_ method needs two players. However, defaulted games should also not
be added unless the result is to be counted for rating. It's perfectly legal
for players not to have a rated result for every round. Indeed, it's valid
for some players not to have any results at all (although, in that case, those
players would not be rated in the tournament).

=end

  class RatedResult
    attr_reader :round, :opponent, :score, :expected_score, :rating_change

    def rate(player)
      player_rating   = player.full_rating?   ? player.rating   : player.performance
      opponent_rating = opponent.full_rating? ? opponent.rating : opponent.performance
      if (player_rating && opponent_rating)
        @expected_score = 1 / (1 + 10 ** ((opponent_rating - player_rating) / 400.0))
        @rating_change  = (@score - @expected_score) * player.kfactor if player.full_rating?
      end
    end

    def ==(other)
      return false unless other.round    == round
      return false unless other.opponent == opponent
      return false unless other.score    == score
      true
    end

    def opponents_score
      1.0 - score
    end

    private

    def initialize(round, opponent, score)
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