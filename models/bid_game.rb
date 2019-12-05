class BidGame < Sequel::Model(DB[:bid_game])
    # REVIEW 这个会有override问题
    # attr_reader :status, :maximum_player_num

    def game_start
        self.status = 1
        return self
    end

    def game_close
        final_single_min_submit = SingleMinSubmit.where(bid_game_id: self.id).group_and_count(:submitted_value).having(count: 1).first

        if (self.status == 1 && final_single_min_submit) then 
            #计算最终赢得的数字
            
            self.final_single_min = final_single_min_submit[:submitted_value]

            #计算最终赢家
            self.winner_id = SingleMinSubmit.where(bid_game_id: self.id, submitted_value: self.final_single_min).first[:submitted_by]

            #修改状态
            self.status = 2
        end
        return self.save
    end

    def join_bid(user_id, bid_values)
        @current_user = User.where(id: user_id).first
        puts "----------- "+ bid_values+" -----------"
        @bid_values = bid_values.split(',') - ['0']
        @just_had_bids = []
        if @current_user && self.status == 1 then 
            @bid_values.each_with_index do |value, index|
                # 这里需要校验用户是否已经投过这个值，如果已经投过就自动过滤
                @whether_sumitted = SingleMinSubmit.where(bid_game_id: self.id, submitted_by: user_id, submitted_value: value, deleted: 0).first

                if !@whether_sumitted then 
                    @bid_submit = SingleMinSubmit.new(bid_game_id: self.id, submitted_value: value, submitted_by: user_id).save
                    @just_had_bids << @bid_submit
                    self.bids_number += 1
                end
            end
            self.save
        elsif !@current_user then
            puts "User不存在！"
        elsif self.status == 2 then
            puts "遗憾，游戏已经结束啦"
        end

        # 触发达到投注次数就自动结束的逻辑，不需要校验提交的数据
        # @game_bid_num = SingleMinSubmit.where(bid_game_id: self.id, deleted: 0).count(:id)
        if  self.max_bid_num && self.max_bid_num <= self.bids_number then
            game_close
        end

        return @just_had_bids
    end
end