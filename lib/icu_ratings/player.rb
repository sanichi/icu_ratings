# encoding: utf-8

module ICU
  #
  # == Adding Players to Tournaments
  #
  # You don't directly create players, rather you add them to tournaments with the _add_player_ method.
  #
  #   t = ICU::RatedTournament.new
  #   t.add_player(1)
  #
  # There is only one mandatory parameter - the player number - which can be any integer value
  # except player numbers must be unique in each tournament:
  #
  #   t.add_player(2)    # fine
  #   t.add_player(2)    # attempt to add a second player with the same number - exception!
  #
  # == Retrieving Players from Tournaments
  #
  # Player objects can be retrieved from ICU::RatedTournament objects with the latter's _player_ method
  # in conjunction with the appropriate player number:
  #
  #   p = t.player(2)
  #   p.num              # 2
  #
  # Or the player object can be saved from the return value from _add_player_:
  #
  #   p = t.add_player(-2)
  #   p.num             # -2
  #
  # If the number supplied to _player_ is an invalid player number, the method returns _nil_.
  #
  # Different types of players are signalled by different combinations of the three optional
  # parameters: _rating_, _kfactor_ and _games_.
  #
  # == Full Ratings
  #
  # Rated players have a full rating and a K-factor and are added by including valid values for those two parameters:
  #
  #   p = t.add_player(3, :rating => 2000, :kfactor => 16)
  #   p.type             # :rated
  #
  # == Provisional Ratings
  #
  # Players that don't yet have a full rating but do have a provisonal rating estimated on some number
  # of games played prior to the tournament are indicated by values for the _rating_ and _games_ parameters:
  #
  #   p = t.add_player(4, :rating => 1600, :games => 10)
  #   p.type             # :provisional
  #
  # The value for the number of games should not exceed 19 since players with 20 or more games
  # should have a full rating.
  #
  # == Fixed Ratings
  #
  # Players with fixed ratings just have a rating - no K-factor or number of previous games.
  # When the tournament is rated, these players will have their tournament performance ratings
  # calculated but the value returned by the method _new_rating_ will just be the rating they
  # started with. Typically these are foreign players with FIDE ratings who are not members of
  # the ICU and for whom ICU ratings are not desired.
  #
  #   p = t.add_player(6, :rating => 2500)
  #   p.type             # :foreign
  #
  # == No Rating
  #
  # Unrated players who do not have any previous rated games at all are indicated by leaving out any values for
  # _rating_, _kfactor_ or _games_.
  #
  #   p = t.add_player(5)
  #   p.type             # :unrated
  #
  # == Invalid Combinations
  #
  # The above four types of players (_rated_, _provisional_, _unrated_, _foreign_) are the only
  # valid ones and any attempt to add players with other combinations of the attributes
  # _rating_, _kfactor_ and _games_ will cause an exception. For example:
  #
  #   t.add_player(7, :rating => 2000, :kfactor => 16, :games => 10)   # exception! - cannot have both kfactor and games
  #   t.add_plater(7, :kfactor => 16)                                  # exception! - kfactor makes no sense without a rating
  #
  # == String Input Values
  #
  # Although _rating_ and _kfactor_ are held as Float values and _games_ and _num_ (the player number) as Fixnums,
  # all these parameters can be specified using strings, even when padded with whitespace.
  #
  #   p = t.add_player("  0  ", :rating => "  2000.5  ", :kfactor => "  20.5  ")
  #   p.num            # 0 (Fixnum)
  #   p.rating         # 2000.5 (Float)
  #   p.kfactor        # 20.5 (Float)
  #
  # == Calculation of K-factors
  #
  # Rather than pre-calculating the value to set for a rated player's K-factor, the RatedPlayer class can itself
  # calculate K-factors if the releavant information is supplied. ICU K-factors depend not only on a player's
  # rating, but also on their age and experience. Therefore, supply a hash, instead of a numerical value, for the
  # _kfactor_ attribute with values set for date-of-birth (_dob_) and date joined (_joined_):
  #
  #   t = Tournament.new(:start => "2010-07-10")
  #   p = t.add_player(1, :rating => 2225, :kfactor => { :dob => "1993-12-20", :joined => "2004-11-28" })
  #   p.kfactor        # 16.0
  #
  # For this to work the tournament's optional start date must be set to enable the player's age and
  # experience at the start of the tournament be to calculated. The ICU K-factor rules are:
  #
  # * 16 for players rated 2100 and over, otherwise
  # * 40 for players aged under 21, otherwise
  # * 32 for players who have been members for less than 8 years, otherwise
  # * 24
  #
  # If you want to calculate K-factors accrding to some other, non-ICU scheme, then override the
  # static method _kfactor_ of the RatedPlayer class and pass in a hash of whatever key-value pairs
  # it requires as the value associated with _kfactor_ key in the _add_player_ method.
  #
  # == Description Parameter
  #
  # There is one other optional parameter, _desc_ (short for "description"). It has no effect on player
  # type or rating calculations and it cannot be used to retrieve players from a tournament (only the
  # player number can be used for that). Its only use is to attach additional arbitary data to players.
  # Any object can be used and descriptions don't have to be unique. The attribute's typical use, if
  # it's used at all, is expected to be for player names and/or ID numbers, in the form of String values.
  #
  #   t.add_player(8, :rating => 2800, :desc => 'Gary Kasparov (4100018)')
  #   t.player(8).desc    # "Gary Kasparov (4100018)"
  #
  # == After the Tournament is Rated
  #
  # After the <em>rate!</em> method has been called on the ICU::RatedTournament object, the results
  # of the rating calculations are available via various methods of the player objects:
  #
  # _new_rating_::     This is the player's new rating. For rated players it is their old rating
  #                    plus their _rating_change_ plus their _bonus_ (if any). For provisional players
  #                    it is their performance rating including their previous games. For unrated
  #                    players it is their tournament performance rating. New ratings are not
  #                    calculated for foreign players so this method just returns their start _rating_.
  # _rating_change_::  This is calculated from a rated player's old rating, their K-factor and the sum
  #                    of expected scores in each game. The same as the difference between the old and
  #                    new ratings (unless there is a bonus). Not available for other player types.
  # _performance_::    This returns the tournament rating performance for rated, unrated and
  #                    foreign players. For provisional players it returns a weighted average
  #                    of the player's tournament performance and their previous games. For
  #                    provisional and unrated players it is the same as _new_rating_.
  # _expected_score_:: This returns the sum of expected scores over all results for all player types.
  #                    For rated players, this number times the K-factor gives their rating change.
  #                    It is calculated for provisional, unrated and foreign players but not actually
  #                    used to estimate new ratings (for provisional and unrated players performance
  #                    estimates are used instead).
  # _bonus_::          The bonus received by a rated player (usually zero). Only available for rated
  #                    players.
  # _pb_rating_::      A rated player's pre-bonus rating (rounded). Only for rated players and
  #                    returns nil for players who are ineligible for a bonus.
  # _pb_performance_:: A rated player's pre-bonus performance (rounded). Only for rated players and
  #                    returns nil for players ineligible for a bonus.
  #
  # == Unrateable Players
  #
  # If a tournament contains groups of provisonal or unrated players who play games
  # only amongst themselves and not against any rated or foreign opponents, they can't
  # be rated. This is indicated by a value of _nil_ returned from the _new_rating_
  # method.
  #
  class RatedPlayer
    attr_reader :num, :type, :performance, :results
    attr_accessor :desc

    def self.factory(num, args={}) # :nodoc:
      num     = check_num(num)
      rating  = check_rating(args[:rating])
      kfactor = check_kfactor(args[:kfactor])
      games   = check_games(args[:games])
      desc    = args[:desc]
      case
        when  rating &&  kfactor && !games then FullRating.new(num, desc, rating, kfactor)
        when  rating && !kfactor &&  games then ProvRating.new(num, desc, rating, games)
        when  rating && !kfactor && !games then FrgnRating.new(num, desc, rating)
        when !rating && !kfactor && !games then NoneRating.new(num, desc)
        else  raise "invalid combination of player attributes"
      end
    end

    def self.check_num(arg) # :nodoc:
      num = arg.to_i
      raise "invalid player num (#{arg})" if num == 0 && !arg.to_s.match(/^\s*\d/)
      num
    end

    def self.check_rating(arg) # :nodoc:
      return unless arg
      rating = arg.to_f
      raise "invalid player rating (#{arg})" if rating == 0.0 && !arg.to_s.match(/^\s*\d/)
      rating
    end

    def self.check_kfactor(arg) # :nodoc:
      return unless arg
      kfactor = arg.to_f
      raise "invalid player k-factor (#{arg})" if kfactor <= 0.0
      kfactor
    end

    def self.check_games(arg) # :nodoc:
      return unless arg
      games = arg.to_i
      raise "invalid number of games (#{arg})" if games <= 0 || games >= 20
      games
    end

    # Calculate a K-factor according to ICU rules.
    def self.kfactor(args)
      %w{rating start dob joined}.each { |a| raise "missing #{a} for K-factor calculation" unless args[a.to_sym] }
      case
      when args[:rating] >= 2100 then
        16
      when ICU::Util.age(args[:dob], args[:start]) < 21 then
        40
      when ICU::Util.age(args[:joined], args[:start]) < 8 then
        32
      else
        24
      end
    end

    def reset # :nodoc:
      @performance = nil
      @estimated_performance = nil
    end

    class FullRating < RatedPlayer # :nodoc:
      attr_reader :rating, :kfactor, :bonus, :pb_rating, :pb_performance

      def initialize(num, desc, rating, kfactor)
        @type = :rated
        @rating = rating
        @kfactor = kfactor
        @bonus = 0
        super(num, desc)
      end

      def reset
        @pb_rating = nil
        @pb_performance = nil
        @bonus_rating = nil
        @bonus = 0
        super
      end

      def rating_change
        @results.inject(0.0) { |c, r| c + (r.rating_change || 0.0) }
      end

      def new_rating(type=nil)
        case type
        when :start
          @rating                          # the player's start rating
        when :opponent
          @bonus_rating || @rating         # the rating used for opponents during the calculations
        else
          @rating + rating_change + @bonus # the player's final rating
        end
      end

      def calculate_bonus
        return if @kfactor <= 24 || @results.size <= 4 || @rating >= 2100
        change = rating_change
        # Remember the key inputs to the calculation
        @pb_rating = (@rating + change).round
        @pb_performance = @performance.round
        # Calculate the bonus.
        return if change <= 35 || @rating + change >= 2100
        threshold = 32 + 3 * (@results.size - 4)
        bonus = (change - threshold).round
        return if bonus <= 0
        bonus = (1.25 * bonus).round if kfactor >= 40
        # Determine if it should be capped or not.
        [2100, @performance].each { |max| bonus = (max - @rating - change).round if @rating + change + bonus >= max }
        return if bonus <= 0
        # Store the value.
        @bonus_rating = @rating + change + bonus
        @bonus = bonus
      end

      def update_bonus
        @bonus_rating = @rating + @bonus + rating_change if @bonus_rating
      end
    end

    class ProvRating < RatedPlayer # :nodoc:
      attr_reader :rating, :games

      def initialize(num, desc, rating, games)
        @type = :provisional
        @rating = rating
        @games = games
        super(num, desc)
      end

      def new_rating(type=nil)
        performance
      end

      def average_performance(new_performance, new_games)
        old_performance = games * rating
        old_games       = games
        (new_performance + old_performance) / (new_games + old_games)
      end
    end

    class NoneRating < RatedPlayer # :nodoc:
      def initialize(num, desc)
        @type = :unrated
        super(num, desc)
      end

      def new_rating(type=nil)
        performance
      end
    end

    class FrgnRating < RatedPlayer # :nodoc:
      attr_reader :rating

      def initialize(num, desc, rating)
        @type = :foreign
        @rating = rating
        super(num, desc)
      end

      def new_rating(type=nil)
        rating
      end
    end

    def expected_score
      @results.inject(0.0) { |e, r| e + (r.expected_score || 0.0) }
    end

    def score
      @results.inject(0.0) { |e, r| e + r.score }
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

    def rate!(update_bonus=false) # :nodoc:
      @results.each { |r| r.rate!(self) }
      self.update_bonus if update_bonus && respond_to?(:update_bonus)
    end

    def estimate_performance # :nodoc:
      games, performance = results.inject([0,0.0]) do |sum, result|
        rating = result.opponent.new_rating(:opponent)
        if rating
          sum[0]+= 1
          sum[1]+= rating + (2 * result.score - 1) * 400.0
        end
        sum
      end
      @estimated_performance = average_performance(performance, games) if games > 0
    end

    def average_performance(performance, games) # :nodoc:
      performance / games
    end

    def update_performance(thresh) # :nodoc:
      stable = case
      when  @performance &&  @estimated_performance then
        (@performance - @estimated_performance).abs < thresh
      when !@performance && !@estimated_performance then
        true
      else
        false
      end
      @performance = @estimated_performance if @estimated_performance
      stable
    end

    def ==(other) # :nodoc:
      return false unless other.is_a? ICU::RatedPlayer
      num == other.num
    end

    private

    def initialize(num, desc) # :nodoc:
      @num     = num
      @desc    = desc
      @results = []
    end
  end
end