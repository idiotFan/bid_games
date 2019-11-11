class BidGame < Sequel::Model(DB[:bid_game])
    # REVIEW 这个会有override问题
    # attr_reader :status, :maximum_player_num

    # def initialize(game_type, game_info, max_num, bid_fee, opened_by)
    #     @game_info = game_info
    #     @game_type = game_type
    #     @maximum_player_num = max_num
    #     @single_bid_fee = bid_fee
    #     @opened_by = opened_by
    # end

    def game_start
        self.status = 1
        return self
    end

    def game_close
        self.status = 2
        return self
    end
end