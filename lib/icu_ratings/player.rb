module ICU

=begin rdoc

== Adding Players to Tournaments

You don't directly create players, rather you add them to tournaments with the _add_player_ method.

  t = ICU::RatedTournament.new
  t.add_player(1)

There is only one mandatory parameter - the player number - which can be any integer value
except player numbers must be unique in each tournament:

  t.add_player(2)    # fine
  t.add_player(2)    # attempt to add a second player with the same number - exception!

== Retrieving Players from Tournaments

Player objects can be retrieved from ICU::RatedTournament objects with the latter's _player_ method
in conjunction with the appropriate player number:

  p = t.player(2)
  p.num              # 2

Or the player object can be saved from the return value from _add_player_:

  p = t.add_player(-2)
  p.num             # -2

If the number supplied to _player_ is an invalid player number, the method returns _nil_.

Different types of players are signalled by different combinations of the three optional
parameters: _rating_, _kfactor_ and _games_.

== Full Ratings

Rated players have a full rating and a K-factor and are added by including valid values for those two parameters:

  p = t.add_player(3, :rating => 2000, :kfactor => 16)
  p.type             # :rated

== Provisional Ratings

Players that don't yet have a full rating but do have a provisonal rating estimated on some number
of games played prior to the tournament are indicated by values for the _rating_ and _games_ parameters:

  p = t.add_player(4, :rating => 1600, :games => 10)
  p.type             # :provisional

The value for the number of games should not exceed 19 since players with 20 or more games
should have a full rating.

== Fixed Ratings

Players with fixed ratings just have a rating - no K-factor or number of previous games.
When the tournament is rated, these players will have their tournament performance ratings
calculated but the value returned by the method _new_rating_ will just be the rating they
started with. Typically these are foreign players with FIDE ratings who are not members of
the ICU and for whom ICU ratings are not desired.

  p = t.add_player(6, :rating => 2500)
  p.type             # :foreign

== No Rating

Unrated players who do not have any rated games at all are indicated by leaving out any values for
_rating_, _kfactor_ or _games_.

  p = t.add_player(5)
  p.type             # :unrated
  
== Invalid Combinations

The above four types of players (_rated_, _provisional_, _unrated_, _foreign_) are the only
valid ones and any attempt to add players with other combinations of the attributes
_rating_, _kfactor_ and _games_ will cause an exception. For example:

  t.add_player(7, :rating => 2000, :kfactor => 16, :games => 10)   # exception! - cannot have both kfactor and games
  t.add_plater(7, :kfactor => 16)                                  # exception! - kfactor makes no sense without a rating

== String Input Values

Although _rating_ and _kfactor_ are held as Float values and _games_ and _num_ (the player number) as Fixnums,
all these parameters can be specified using strings, even when padded with whitespace.

  p = t.add_player("  0  ", :rating => "  2000.5  ", :kfactor => "  20.5  ")
  p.num            # 0 (Fixnum)
  p.rating         # 2000.5 (Float)
  p.kfactor        # 20.5 (Float)

== Description Parameter

There is one other optional parameter, _desc_ (short for "description"). It has no effect on player
type or rating calculations and it cannot be used to retrieve players from a tournament (only the
player number can be used for that). Its only use is to attach additional arbitary data to players.
Any object can be used and descriptions don't have to be unique. The attribute's typical use,
if it's used at all, is expected to be for player names in the form of String values.

  t.add_player(8, :rating => 2800, :desc => 'Gary Kasparov (4100018)')
  t.player(8).desc    # "Gary Kasparov (4100018)"

== After the Tournament is Rated

After the <em>rate!</em> method has been called on the ICU::RatedTournament object, the results
of the rating calculations are available via various methods of the player objects:
_new_rating_, _rating_change_, _performance_, _expected_score_.

== Unrateable Players

If a tournament contains groups of provisonal or unrated players who play games
only amongst themselves and not against any rated or foreign opponents, they can't
be rated. This is indicated by a value of _nil_ returned from the _new_rating_
method.

=end

  class RatedPlayer
    attr_reader :num, :rating, :kfactor, :games
    attr_accessor :desc

    # After the tournament has been rated, this is the player's new rating. For rated players this is the old rating
    # plus the _rating_change_. For provisional players it is their performance rating, including their previous
    # games. For unrated players it is their tournament performance rating. For foreign players it is the same
    # as their start _rating_.
    def new_rating
      full_rating? ? rating + rating_change : performance
    end

    # After the tournament has been rated, this is the difference between the old and new ratings for
    # rated players, based on sum of expected scores in each games and the player's K-factor.
    # Zero for all other types of players.
    def rating_change
      @results.inject(0.0) { |c, r| c + (r.rating_change || 0.0) }
    end

    # After the tournament has been rated, this returns the sum of expected scores over all results.
    # Although this is calculated for provisional and unrated players it is not used to estimate their
    # new ratings. For rated players, this number times the K-factor gives the change in rating.
    def expected_score
      @results.inject(0.0) { |e, r| e + (r.expected_score || 0.0) }
    end
    
    # After the tournament has been rated, this returns the tournament rating performance for
    # rated, unrated and foreign players. For provisional players it returns a weighted average
    # of the player's tournament performance and their previous games. For provisional and
    # unrated players it is the same as _new_rating_.
    def performance
      @performance
    end
    
    # Returns an array of the player's results (ICU::RatedResult) in round order.
    def results
      @results
    end

    # The sum of the player's scores in all rounds in which they have a result.
    def score
      @results.inject(0.0) { |e, r| e + r.score }
    end
    
    # Returns the type of player as a symbol: one of _rated_, _provisional_, _unrated_ or _foreign_.
    def type
      @type
    end
    
    def add_result(result) # :nodoc:
      raise "invalid result (#{result.class})" unless result.is_a? ICU::RatedResult
      raise "players cannot score results against themselves" if self == result.opponent
      duplicate = false
      @results.each do |r|
        if r.round == result.round
          raise "inconsistent result in round #{r.round}" unless r == result
          duplicate = true
        end
      end
      return if duplicate
      @results << result
      @results.sort!{ |a,b| a.round <=> b.round }
    end
   
    def rate! # :nodoc:
      @results.each { |r| r.rate!(self) }
    end

    def full_rating? # :nodoc:
      @type == :rated || @type == :foreign
    end

    def init_performance # :nodoc:
      @performance = nil
      @estimated_performance = nil
    end

    def estimate_performance # :nodoc:
      new_games, new_performance = results.inject([0,0.0]) do |sum, result|
        opponent = result.opponent
        if opponent.full_rating? || opponent.performance
          sum[0]+= 1
          sum[1]+= (opponent.full_rating? ? opponent.rating : opponent.performance) + (2 * result.score - 1) * 400.0
        end
        sum
      end
      if new_games > 0
        old_games, old_performance = type == :provisional ? [games, games * rating] : [0, 0.0]
        @estimated_performance = (new_performance + old_performance) / (new_games + old_games)
      end
    end

    def update_performance # :nodoc:
      stable = case
      when  @performance &&  @estimated_performance then (@performance - @estimated_performance).abs < 0.5
      when !@performance && !@estimated_performance then true
      else false
      end
      @performance = @estimated_performance if @estimated_performance
      stable
    end

    def ==(other) # :nodoc:
      return false unless other.is_a? ICU::RatedPlayer
      num == other.num
    end

    private

    def initialize(num, opt={}) # :nodoc:
      self.num = num
      [:rating, :kfactor, :games, :desc].each { |atr| self.send("#{atr}=", opt[atr]) unless opt[atr].nil? }
      @results = []
      @type = deduce_type
    end

    def num=(num)
      @num = num.to_i
      raise "invalid player num (#{num})" if @num == 0 && !num.to_s.match(/^\s*\d/)
    end

    def rating=(rating)
      @rating = rating.to_f
      raise "invalid player rating (#{rating})" if @rating == 0.0 && !rating.to_s.match(/^\s*\d/)
    end

    def kfactor=(kfactor)
      @kfactor = kfactor.to_f
      raise "invalid player k-factor (#{kfactor})" if @kfactor <= 0.0
    end

    def games=(games)
      @games = games.to_i
      raise "invalid number of games (#{games})" if @games <= 0 || @games >= 20
    end

    def deduce_type
      case
        when  @rating &&  @kfactor && !@games then :rated
        when  @rating && !@kfactor &&  @games then :provisional
        when  @rating && !@kfactor && !@games then :foreign
        when !@rating && !@kfactor && !@games then :unrated
        else  raise "invalid combination of player attributes"
      end
    end
  end
end