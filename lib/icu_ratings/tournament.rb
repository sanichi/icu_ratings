module ICU

=begin rdoc

== Todo

=end

  class RatedTournament
    attr_reader :desc

    def add_player(num, args={})
      raise "player with number #{num} already exists" if @player[num]
      @player[num] = ICU::RatedPlayer.new(num, args)
    end

    def add_result(round, player, opponent, score)
      n1 = player.is_a?(ICU::RatedPlayer) ? player.num : player.to_i
      n2 = opponent.is_a?(ICU::RatedPlayer) ? opponent.num : opponent.to_i
      p1 = @player[n1] || raise("no such player number (#{n1})")
      p2 = @player[n2] || raise("no such player number (#{n2})")
      r1 = ICU::RatedResult.new(round, p2, score)
      r2 = ICU::RatedResult.new(round, p1, r1.opponents_score)
      p1.add_result(r1)
      p2.add_result(r2)
    end

    def rate
      performance_ratings
      players.each { |p| p.rate }
    end

    def players
      @player.keys.sort.map{ |num| @player[num] }
    end

    def player(num)
      @player[num]
    end

    private

    def initialize(opt={})
      [:desc].each { |atr| self.send("#{atr}=", opt[atr]) unless opt[atr].nil? }
      @player = Hash.new
    end

    def desc=(desc)
      @desc = desc.to_s
    end
    
    def performance_ratings
      @player.values.each { |p| p.init_performance }
      stable, count = false, 0
      while !stable && count < 30
        @player.values.each { |p| p.estimate_performance }
        stable = @player.values.inject(true) { |ok, p| p.update_performance && ok }
        count+= 1
      end
      raise "performance rating estimation did not converge" unless stable
    end
  end
end
