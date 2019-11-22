require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/namespace'

# require 'kaminari' 
# require 'aasm'
require 'require_all'
require 'json' # so that can directly use Hash.to_json 

# build open hashes，不过Benchmark表示性能与Struct相比非常差，所以不建议用
# require 'ostruct'
# require 'recursive-open-struct'

require_all 'db'
require_all 'models'
require_all 'serializers'
require_all 'token'
require_all 'utils'

#开启Sinatra的Session功能
enable :sessions
set :bind, '0.0.0.0'

# 将server绑定到80端口上，以便能够直接访问
set :port, 8080

register Sinatra::Reloader


get '/' do 
    redirect '/bid_games' 
end

get '/app' do 
    erb :app, :layout => false
end


get '/vote' do 
    @title = "Welcome to Voting Demo!"
    @choice = Choice.select(:key, :value)
    erb :index
end

post '/vote/cast' do 
  if params['vote'] 
    if session['current_user'] then 
        @title = "Thanks for your vote!"
        @vote_key = params['vote']
        @vote_value = Choice.where(key: @vote_key).first.value
        @vote = Vote.new(voted_key: @vote_key, voted_by: session['current_user'], created_at: Time.now, updated_at: Time.now).save

        erb :cast
    else 
        redirect '/login'
    end
  else 
    @title = "请选择一个选项！"
  end
end

get '/vote/results' do 
    @choice = Choice.distinct(:key, :value).select(:key, :value).as_hash(:key, :value)
    
    #输出是直接的Hash的话需要处理排序的问题，因为Hash本身是无序的！
    @vote_counts = Vote.group_and_count(:voted_key).order(:count).reverse.as_hash(:voted_key, :count)

    erb :results
end

# 游戏首页，展示所有游戏和直接开一局游戏
get '/bid_games' do 
    @title = "Bid游戏厅"
    @biding_game = BidGame.where(status: 1, deleted: 0)
    erb :bid_games
end

get '/bid_games/archived' do 
    @title = "已经结束的游戏"
    @biding_game = BidGame.where(status: 2, deleted: 0)
    erb :bid_games
end


# 渲染游戏详情页
get '/bid_games/:game_id' do 
    Status = {
        1 => '进行中',
        2 => '已结束'
    }
        
    @current_game = BidGame.where(id: params[:game_id]).first
    if !@current_game then 
        redirect '/bid_games'
        break
    end 
    
    @game_join_records = SingleMinSubmit.where(bid_game_id: params[:game_id]).left_join(:user, id: :submitted_by).select{[submitted_value, submitted_by, user__username, single_min_game_submittion__created_at]}.order(:submitted_value)
    
    @game_join_users = SingleMinSubmit.group_and_count(:bid_game_id, :submitted_by).having(bid_game_id: @current_game.id)

    @game_opened_by = User.where(id: @current_game.opened_by).first
    @title = @current_game.name

    @current_user = User.where(id: session['current_user']).first
    if @current_user then 
        @current_user_join_records = SingleMinSubmit.where(bid_game_id: params[:game_id], submitted_by: @current_user.id).order(:submitted_value)
    end

    # 如果游戏是结束状态，返回最新的当前结果
    @atari =SingleMinSubmit.where(bid_game_id: params[:game_id]).group_and_count(:submitted_value).having(count: 1).first
    if @atari then 
        @final_winner_submit = SingleMinSubmit.where(bid_game_id: params[:game_id], submitted_value: @atari.submitted_value).first
        @final_winner = User.where(id: @final_winner_submit.submitted_by).first
    end

    erb :game_detail
end


# 创建一个游戏，成功后直接跳转游戏详情页
post '/bid_games/create' do 
    @title = params[:game_info]
    @game_info = params[:game_info]
    @game_name = params[:game_name]
    @player_num = params[:max_player_number]
    @max_bid_num = params[:max_bid_num]
    @bid_fee = params[:single_bid_fee]
    @game_type = params[:game_type]
    @current_game = {}
    @game_opened_by = User.where(id: session['current_user']).first
    
    #判定是否正常登录
    if @game_opened_by then 
        #创建游戏 
        @current_game = BidGame.new(type: @game_type, name: @game_name, game_info: @game_info, maximum_player_num: @player_num, max_bid_num: @max_bid_num, single_bid_fee: @bid_fee, opened_by: @game_opened_by.id).game_start.save
    else 
        session['redirect_to'] = "/bid_games"
        redirect '/login'
    end
    
    # "You have created a #{@player_num} people palying game to play #{@game_info} ！Everyone would pay #{@bid_fee} to play once."
    # 直接去详情页查看已经创建成功的游戏
    redirect "/bid_games/#{@current_game.id}"
end


# 投注一个已经存在的游戏
post '/bid_games/:game_id/join' do 
    # 'Thanks for your bids!'
    @current_user = User.where(id: session['current_user']).first
    @current_game = BidGame.where(id: params[:game_id]).first
    @bid_values = params[:bid_values].split(',') - ['0']
    if @current_user && @current_game.status == 1 then 
        @bid_values.each_with_index do |value, index|
            # 这里需要校验用户是否已经投过这个值，如果已经投过就自动过滤
            @whether_sumitted = SingleMinSubmit.where(bid_game_id: @current_game.id, submitted_by: @current_user.id,  submitted_value: value, deleted: 0).first
            if !@whether_sumitted then 
                @bid_submit = SingleMinSubmit.new(bid_game_id: @current_game.id, submitted_value: value, submitted_by: @current_user.id).save 
            end
        end

        # 触发达到人数就自动结束的逻辑
        @game_join_users = SingleMinSubmit.group_and_count(:bid_game_id, :submitted_by).having(bid_game_id: @current_game.id)
        if  @current_game.maximum_player_num && @current_game.maximum_player_num <= @game_join_users.count then
            @current_game.game_close.save
        end

        # 触发达到投注次数就自动结束的逻辑
        @game_bid_num = SingleMinSubmit.where(bid_game_id: @current_game.id).count(:id)
        if  @current_game.max_bid_num && @current_game.max_bid_num <= @game_bid_num then
            @current_game.game_close.save
        end

    elsif !@current_user then
        session['redirect_to'] = "/bid_games/#{@current_game.id}"
        redirect '/login'
    elsif @current_game.status == 2 then
        "遗憾，游戏已经结束啦"
    end
    
    redirect "/bid_games/#{@current_game.id}"
end


# 创建者/庄家 直接结束这个游戏
get '/bid_games/:game_id/finish' do 
    @current_user = User.where(id: session['current_user']).first

    @current_game = BidGame.where(id: params[:game_id]).first

    if !@current_user then
        session['redirect_to'] = "/bid_games/#{@current_game.id}"
        redirect '/login'
    elsif @current_user.id == @current_game.opened_by.to_i && @current_game.status == 1 then 
        @current_game.game_close.save
    elsif @current_game.status == 2 then
        "遗憾，游戏已经结束啦"
    end
    
    redirect "/bid_games/#{@current_game.id}"
end



# 登录页面
get '/login/:redirect_back' do
    @title = "请登录/注册你的账号"
    session['redirect_to'] = '/bid_games/'+params[:redirect_back]
    erb :login
end 

get '/login' do
    @title = "请登录/注册你的账号"
    erb :login
end 

# 登录/注册一体化验证逻辑以及跳转结果
post '/login_anyway' do 
    auth_result = auth_login(params['username'], params['password'])
    
    if auth_result[:login_user] then 
        # REVIEW 写入到session里面去，不过如果一旦服务器重启就断线了
        session['current_user'] = auth_result[:login_user].id

        # REVIEW 跳回事先已经存储好的需要跳回的链接，如果没有就去首页
        redirect session['redirect_to'] || '/'
    else
        logger.info auth_result 
        auth_result.to_json
    end
end


#-----------------用API的方式来实现操作votes--------------------

namespace '/api/v1' do
    
    
    get '/votes' do
        content_type :json
        # status 201 #直接设定返回状态
        # json = VoteSerializer.new(Vote.all,{ fields:{ vote:[:voted_key] } }).serialized_json
        # json = VoteSerializer.new(Vote.select(:voted_by, :voted_key, :created_at).all).serialized_json
        # json = VoteSerializer.new(Vote.all).serialized_json
        res = {code: 200, message:{}, data: {votes:{}}}
        res[:data][:votes] = Vote.select(:voted_by, :voted_key, :created_at)
        res = res.to_json
    end
    
    
    post '/login_anyway' do
        content_type :json

        res = {code: 200, message:{}, data: {login_user_id:{}}}
        auth_result = auth_login(params['username'], params['password'])
        res[:data][:login_user_id] = auth_result[:login_user].id
        res[:message] = auth_result[:message]
        res[:token] = auth_result[:token]

        session['current_user'] = auth_result[:login_user].id
        
        res = res.to_json
    end    

    
    post '/verify_token' do
        content_type :json
        res = {code: 200, message:{}, data: {verify_login_user:{}}}
        token_res = verify_token(params['user_token'])
        res[:message] = token_res[:message]
        res[:data][:verify_login_user] = token_res[:verify_login_user]

        res.to_json
    end


    get '/bid_games' do 
        content_type :json
        res = {code: 200, data: {bid_games:{}}}
        # 分表和别名都得用Symbol的写法
        res[:data][:bid_games] = BidGame.where(bid_game__deleted: 0)
        .left_join(:user, id: :opened_by).select{[
            :bid_game__id___game_id, 
            :bid_game__name___game_name, 
            :bid_game__game_info, 
            :bid_game__type___game_type, 
            :bid_game__single_bid_fee, 
            :bid_game__status___game_status, 
            :bid_game__opened_by___game_owner_id, 
            :bid_game__created_at___game_created_at, 
            :user__username, 
            :user__nickname___user_nickname, 
            :bid_game__max_bid_num, 
            :bid_game__maximum_player_num
            ]}.order(:bid_game__created_at).reverse
        
        status 201
        
        res.to_json
    end


    get '/bid_game_bid_records' do 
        content_type :json
        res = {code: 200, message:{}, data: {my_bids:{}, bid_records:{}}}

        res[:data][:my_bids] = SingleMinSubmit.where(bid_game_id: params[:game_id], submitted_by: session['current_user']).left_join(:user, id: :submitted_by).select{[
            :single_min_game_submittion__submitted_value, 
            :single_min_game_submittion__submitted_by___submitted_by_user_id, 
            :user__username, 
            :single_min_game_submittion__created_at___submitted_at
        ]}.order(:submitted_at).reverse
        
        # 需要判定给不给所有记录
        if BidGame.where(id: params[:game_id]).first.status == 2 then 
            res[:data][:bid_records] = SingleMinSubmit.where(bid_game_id: params[:game_id]).left_join(:user, id: :submitted_by).select{[
                :single_min_game_submittion__submitted_value, 
                :single_min_game_submittion__submitted_by___submitted_by_user_id, 
                :user__username, 
                :single_min_game_submittion__created_at___submitted_at
            ]}.order(:submitted_value)
        else
            res[:message] = '游戏结束后才会公布所有投注记录哦~'
        end
        
        status 201
        
        res.to_json
    end

    post '/bid_game/join' do
    
    end


    post '/bid_game/finish' do
    
    end


    post '/bid_game/create' do
        content_type :json
        res = {code: 200, message:{}, data: {created_game:{}}}

        @game_info = params[:game_info]
        @game_name = params[:game_name]
        @max_bid_num = params[:max_bid_num]
        @bid_fee = params[:single_bid_fee]
        @game_type = params[:game_type]
        @user_token = params['user_token']

        res[:message] = session['current_user']

        #判定是否已经正常登录
        # if session['current_user'] then 
        #     #创建游戏 
        #     res[:data][:created_game] = BidGame.new(type: @game_type, name: @game_name, game_info: @game_info, max_bid_num: @max_bid_num, single_bid_fee: @bid_fee, opened_by: session['current_user']).game_start.save
        # else 
        #     res[:message] = "登录之后才可以创建游戏哦~"
        # end

        res.to_json
    end

end

