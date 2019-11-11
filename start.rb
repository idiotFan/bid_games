require 'sinatra'
require 'awesome_print'
require 'kaminari' 
require 'aasm'
require 'require_all'
require 'json' # so that can directly use Hash.to_json 

# build open hashes，不过Benchmark表示性能与Struct相比非常差，所以不建议用
require 'ostruct'
require 'recursive-open-struct'

require_all 'db'
require_all 'models'
require_all 'serializers'
require_all 'token'
require_all 'utils'

#开启Sinatra的Session功能
enable :sessions
set :bind, '0.0.0.0'

get '/' do 
    redirect '/bid_games' 
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
    else redirect '/login'
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
    @title = "想玩哪一个Bid游戏呢？"
    @biding_game = BidGame.where(status: 1, deleted: 0)
    erb :bid_games
end

get '/bid_games/archived' do 
    @title = "已经结束的游戏"
    @biding_game = BidGame.where(status: 1, deleted: 0)
    erb :bid_games
end


# 渲染游戏详情页
get '/bid_games/:game_id' do 
    @current_game = BidGame.where(id: params[:game_id]).first
    if !@current_game then 
        redirect '/404'
        break
    end 
    @game_join_records = SingleMinSubmit.where(bid_game_id: params[:game_id]).order(:submitted_value)
    @game_join_users = SingleMinSubmit.group_and_count(:bid_game_id, :submitted_by).having(bid_game_id: @current_game.id)
    @game_opened_by = User.where(id: @current_game.opened_by).first
    @title = @current_game.name

    @current_user = User.where(id: session['current_user']).first
    if @current_user then 
        @current_user_join_records = SingleMinSubmit.where(bid_game_id: params[:game_id], submitted_by: @current_user.id).order(:created_at).reverse
    end

    # 如果游戏是结束状态，渲染一些额外的东西
    if @current_game.status == 2 then 
        @atari =SingleMinSubmit.where(bid_game_id: params[:game_id]).group_and_count(:submitted_value).having(count: 1).first
        if @atari then 
            @final_winner_submit = SingleMinSubmit.where(submitted_value: @atari.submitted_value).first
            @final_winner = User.where(id: @final_winner_submit.submitted_by).first
        end
    end

    erb :game_detail
end


# 创建一个游戏，成功后直接跳转游戏详情页
post '/bid_games/create' do 
    @title = params[:game_info]
    @game_info = params[:game_info]
    @game_name = params[:game_name]
    @player_num = params[:max_player_number] == ''? params[:max_player_number] : 10
    @bid_fee = params[:single_bid_fee] == ''? params[:single_bid_fee] : 1
    @game_type = params[:game_type]
    @current_game = {}
    @game_opened_by = User.where(id: session['current_user']).first
    
    #判定是否正常登录
    if @game_opened_by then 
        @current_game = BidGame.new(type: @game_type, name: @game_name, game_info: @game_info, maximum_player_num: @player_num, single_bid_fee: @bid_fee, opened_by: @game_opened_by.id).game_start.save

    else redirect '/login'
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
    @bid_values = params[:bid_values].split(',')
    if @current_user && @current_game.status == 1 then 
        @bid_values.each_with_index do |value, index|
            @bid_submit = SingleMinSubmit.new(bid_game_id: @current_game.id, submitted_value: value, submitted_by: @current_user.id).save
        end

        # 重新获取一下单场游戏的参与人数
        @game_join_users = SingleMinSubmit.group_and_count(:bid_game_id, :submitted_by).having(bid_game_id: @current_game.id)
        if  @current_game.maximum_player_num <= @game_join_users.count then
            @current_game.game_close.save
        end
    elsif !@current_user then
        redirect '/login'
    elsif @current_game.status == 2 then
        "遗憾，游戏已经结束啦"
    end
    
    redirect "/bid_games/#{@current_game.id}"
end


# 开局者直接结束这个游戏
get '/bid_games/:game_id/finish' do 
    @current_user = User.where(id: session['current_user']).first

    @current_game = BidGame.where(id: params[:game_id]).first

    if !@current_user then
        redirect '/login'
    elsif @current_user.id == @current_game.opened_by.to_i && @current_game.status == 1 then 
        @current_game.game_close.save
    elsif @current_game.status == 2 then
        "遗憾，游戏已经结束啦"
    end
    
    redirect "/bid_games/#{@current_game.id}"
end



# 登录页面
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
        # TODO 都会跳回首页，太傻了，需要改造 
        redirect '/'
    else
        logger.info auth_result 
        auth_result.to_json
    end
end


#-----------------用API的方式来实现操作votes--------------------

post '/api/v1/get_token' do

end


get '/api/v1/votes' do
    content_type :json
    # status 201 #直接设定返回状态
    # json = VoteSerializer.new(Vote.all,{ fields:{ vote:[:voted_key] } }).serialized_json
    # json = VoteSerializer.new(Vote.select(:voted_by, :voted_key, :created_at).all).serialized_json
    # json = VoteSerializer.new(Vote.all).serialized_json
    res = {code: 200, data: {votes:{}}}
    res[:data][:votes] = Vote.select(:voted_by, :voted_key, :created_at)
    res = res.to_json
end


post '/api/v1/login_anyway' do
    content_type :json
    # json = VoteSerializer.new(Vote.all,{ fields:{ vote:[:voted_key] } }).serialized_json
    # json = VoteSerializer.new(Vote.select(:voted_by, :voted_key, :created_at).all).serialized_json
    # json = VoteSerializer.new(Vote.all).serialized_json
    res = {code: 200, data: {votes:{}}}
    res[:data][:votes] = Vote.select(:voted_by, :voted_key, :created_at)
    res = res.to_json
end

