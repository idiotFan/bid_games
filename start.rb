require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/namespace'
require 'sinatra/cross_origin'

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

#设定跨域请求，接受任何来源
enable :cross_origin

#这个很重要，用来关闭Rack自带的跨域请求保护
set :protection, :except => [:json_csrf]

#跨域设置的具体参数，设置成这样的话就可以接受任何客户端的跨域
set :allow_origin, :any
set :allow_methods, [:get, :post, :options]
set :allow_credentials, true
set :max_age, "1728000"
set :expose_headers, ['Content-Type']

# Prod机器需要更改将server绑定到80端口上，以便能够直接访问
set :port, 8080

register Sinatra::Reloader
register Sinatra::CrossOrigin

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
    
    @bid_values = params[:bid_values]
    @current_game.join_bid(@current_user.id, @bid_values)
    
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
        @current_game.game_close
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


#-----------------用API的方式来实现操作Bid游戏厅，提供给前端--------------------

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
        # puts '------' + params['username'] + '--' + params['password'] + '------'

        request.body.rewind  # 要从这里取Body里面的参数，否则直接取params的参数会取不到
        req_data = JSON.parse request.body.read

        res = {code: 200, message:{}, data: {login_user_id:{}}}
        auth_result = auth_login(req_data['username'], req_data['password'])
        if auth_result[:login_user] then 
            res[:data][:login_user_id] = auth_result[:login_user][:id] 
        end
        res[:message] = auth_result[:message]
        res[:token] = auth_result[:token]
        
        res = res.to_json
    end    

    
    post '/verify_token' do
        content_type :json

        request.body.rewind  # 要从这里取Body里面的参数，否则直接取params的参数会取不到
        req_data = JSON.parse request.body.read

        res = {code: 200, message:{}, verify_login_user:{}}
        token_res = verify_token(req_data['user_token'])
        res[:message] = token_res[:message]
        res[:verify_login_user] = token_res[:verify_login_user]
        res[:verify_username] = token_res[:verify_username]

        res.to_json
    end


    get '/bid_games' do 
        @user_token = params[:user_token]
        content_type :json
        res = {code: 200, data: {bid_games:{}}}

        # 分表和别名都得用Symbol的写法
        res[:data][:bid_games] = BidGame.where(bid_game__deleted: 0)
        .left_join(Sequel.as(:user, :host), :id => :opened_by).left_join(Sequel.as(:user, :winner), :id => :bid_game__winner_id).select{[
            :bid_game__id___game_id, 
            :bid_game__name___game_name, 
            :bid_game__game_info, 
            :bid_game__type___game_type, 
            :bid_game__single_bid_fee, 
            :bid_game__status___game_status, 
            :bid_game__opened_by___game_owner_id, 
            :bid_game__created_at___game_created_at, 
            :bid_game__winner_id___game_winner_id,
            :host__username___host_username, 
            :host__nickname___host_nickname, 
            :bid_game__max_bid_num, 
            :bid_game__maximum_player_num,
            :bid_game__bids_number___game_bids_number,
            :winner__username___winnner_username
            ]}.order(:bid_game__created_at).reverse
        
        res.to_json
    end


    post '/bid_game_detail' do 
        content_type :json
        res = {
            code: 200, 
            message:{}, 
            data: {
                game_detail: {},
                my_bids:{}, 
                whole_bid_records:{}
            }
        }

        request.body.rewind  # 要从这里取Body里面的参数，否则直接取params的参数会取不到
        req_data = JSON.parse request.body.read

        @current_game = BidGame.where(id: req_data['game_id']).first

        # REVIEW 应该要封装到Model层，支持不同类型的bid game

        # 返回game的基本信息
        if @current_game then 
            res[:data][:game_detail] = BidGame.where(bid_game__id: req_data['game_id'])
            .left_join(Sequel.as(:user, :host), :id => :opened_by).left_join(Sequel.as(:user, :winner), :id => :bid_game__winner_id).select{[
                :bid_game__id___game_id, 
                :bid_game__name___game_name, 
                :bid_game__game_info, 
                :bid_game__type___game_type, 
                :bid_game__single_bid_fee, 
                :bid_game__status___game_status, 
                :bid_game__opened_by___game_owner_id, 
                :bid_game__created_at___game_created_at, 
                :bid_game__winner_id___game_winner_id,
                :host__username___host_username, 
                :host__nickname___host_nickname, 
                :bid_game__max_bid_num, 
                :bid_game__maximum_player_num,
                :bid_game__bids_number___game_bids_number,
                :winner__username___winnner_username
            ]}.first
        end

        # 暂时只支持了SINGLE_MIN类型的玩法，之后需要根据不同的玩法给出不同的数据。e.g. PRA 
        # 返回从Token拿到的当前自己已经投注的记录
        @current_user_id = verify_token(req_data['user_token'])[:verify_login_user]
        if @current_user_id then 
            res[:data][:my_bids] = SingleMinSubmit.where(bid_game_id: req_data['game_id'], submitted_by:  @current_user_id).left_join(:user, id: :submitted_by).select{[
                :single_min_game_submittion__submitted_value, 
                :single_min_game_submittion__submitted_by___submitted_by_user_id, 
                :user__username, 
                :single_min_game_submittion__created_at___submitted_at
            ]}.order(:submitted_value)
        end
        
        # 需要判定给不给所有记录和游戏结果，如果是SINGLE_MIN且游戏未结束则不给
        if @current_game[:status] == 2 && @current_game[:type] == 'SINGLE_MIN' then 
            res[:data][:whole_bid_records] = SingleMinSubmit.where(bid_game_id: req_data['game_id']).left_join(:user, id: :submitted_by).select{[
                :single_min_game_submittion__submitted_value, 
                :single_min_game_submittion__submitted_by___submitted_by_user_id, 
                :user__username, 
                :single_min_game_submittion__created_at___submitted_at
            ]}.order(:submitted_value)
        else
            res[:message] = '最小唯一数类的游戏结束后才会公布所有投注记录哦~'
        end
        
        status 201
        
        res.to_json
    end


    post '/bid_game/join' do

        content_type :json
        res = {
            code: 200, 
            message:{}, 
            data: {
                    just_bids:{},
                    just_bids_num:{}
            }
        }

        request.body.rewind  # 要从这里取Body里面的参数，否则直接取params的参数会取不到
        req_data = JSON.parse request.body.read

        @current_user_id = verify_token(req_data['user_token'])[:verify_login_user]
        @current_game = BidGame.where(id: req_data['game_id']).first
        @bid_values = req_data['bid_values']

        p @current_user_id.inspect
        p @current_game.inspect
        p @bid_values.inspect
    
        if @current_user_id  && @current_user_id != @current_game[:opened_by] then 
            if @current_user_id && @current_game && @bid_values.length > 0 then 
                
                # 返回从Token拿到的当前自己已经投注的记录
                @just_bids = @current_game.join_bid(@current_user_id, @bid_values)
                res[:message] = "成功投注了#{@just_bids.length}个值"
                res[:data][:just_bids] = @just_bids
                res[:data][:just_bids_num] = @just_bids.length

            else 
                res[:data][:message] = '参数不合法哈~~'
            end
        elsif @current_user_id == @current_game[:opened_by] then 
            res[:data][:message] = '庄家不可以参与投注哦~'
        else 
            res[:data][:message] = '用户Token已失效哦~'
        end

        status 201
        res.to_json
    end


    post '/bid_game/finish' do
        content_type :json
        res = {
            code: 200, 
            message:{}, 
            data: {
                    finished_games:{}
            }
        }

        request.body.rewind  # 要从这里取Body里面的参数，否则直接取params的参数会取不到
        req_data = JSON.parse request.body.read

        @current_user_id = verify_token(req_data['user_token'])[:verify_login_user]
        @current_game = BidGame.where(id: req_data['game_id']).first

        if @current_game.opened_by == @current_user_id && @current_game.status == 2 then 
            @current_game.game_close.save
            res[:message] = "已成功结束游戏：#{@current_game.name}"
            res[:data][:finished_games] = @current_game
        elsif @current_game.opened_by == @current_user_id then 
            res[:code] = 304
            res[:message] = "这个游戏已经结束了哦~"
        elsif @current_game.status == 1 then 
            res[:code] = 304
            res[:message] = "只有庄家可以直接结束自己的游戏!"
        end
        status 201
        res.to_json
    end


    post '/bid_game/create' do
        content_type :json
        res = {code: 200, message:{}, data: {created_game:{}}}
        
        request.body.rewind  # 要从这里取Body里面的参数，否则直接取params的参数会取不到
        req_data = JSON.parse request.body.read

        @game_info = req_data['game_info']
        @game_name = req_data['game_name']
        @max_bid_num = req_data['max_bid_num']
        @bid_fee = req_data['single_bid_fee']
        @game_type = req_data['game_type']
        @user_token = req_data['user_token']

        # REVIEW 需要根据不同的游戏类型来校验提交的参数
        @game_type = req_data['game_type']
        
        @current_user_id = verify_token(req_data['user_token'])[:verify_login_user]

        # 判定Token是否有效
        if @current_user_id then 
            #创建游戏 
            res[:data][:created_game] = BidGame.new(type: @game_type, name: @game_name, game_info: @game_info, max_bid_num: @max_bid_num, single_bid_fee: @bid_fee, opened_by: @current_user_id).game_start.save
            res[:message] = "游戏创建成功！"
        else 
            res[:message] = "用户Token已失效哦~"
        end
        status 201
        res.to_json
    end


    #----------------- 要实现的API --------------------


    # 获取所有 Travel Plans 的粗略信息
    get '/travel_plans' do 
        content_type :json
        res = {
            code: 200, 
            message: '下一次是去这里呢~', 
            sum: {
                plan_ended: 9
            },
            data: {
                travel_plans:[
                    {
                        id:'',
                        title: '第一次冲绳跨年',
                        my_note: '随便记点什么记点什么blahblah',
                        status: 1,
                        regions: ["JAPAN", "SOUTH_KOREA"],
                        start_date: '2019-12-28',
                        end_date: '2020-01-01',
                        luggage:{
                            estimated_filled: 13,
                            flight_max: 23
                        },
                        estimated_time_taken: 6.5,
                        estimated_money: 25433,
                        shopping_nodes:[
                            {
                                id:'',
                                name: 'Bic Camera · 大型综合电器商场',
                                original_name: '',
                                location: '',
                                my_note: '去购买KK的保温杯、CW姐夫的iPad Pro还有Lupicia的茶叶，手机等等等别的东西',
                                complete_at_date: '2019-12-29'
                            },
                            {
                                id:'',
                                name: '三A百货 · 综合商场',
                                original_name: '',
                                location: '',
                                my_note: '购买HABA的精油购买、资生堂的福袋、购买HABA的精油购买HABA的精油购买HABA的精油购买HABA的精油',
                                complete_at_date: '2019-12-29'
                            },
                            {
                                id:'',
                                name: 'DFS那霸新都心店',
                                original_name: '',
                                location: '',
                                my_note: '购买Coach的包包、各种高级美妆，像是CPB等等等等，其他东西，还有iQos的烟弹',
                                complete_at_date: '2019-12-30'
                            }
                        ]
                    }
                ]
            }
        }
        
        status 200

        res.to_json
    end


    # 根据ID获取一个Travel Plan的详情
    post '/travel_plan' do 
        content_type :json
        
        request.body.rewind
        req_data = JSON.parse request.body.read
        
        res = {
            code: 200, 
            message: '获取成功', 
            data: {
                travel_plan:{
                    title: '第一次冲绳跨年',
                    my_note: '随便记点什么记点什么blahblah',
                    status: 1,
                    regions: ["JAPAN", "SOUTH_KOREA"],
                    start_date: '2019-12-28',
                    end_date: '2020-01-01',
                    luggage:{
                        estimated_filled: 13,
                        flight_max: 23
                    },
                    sum: {
                        s_nodes: 9,
                        b_nodes: 10,
                        purchase_amount: 25000,
                    },
                    estimated_time_taken: 6.5,
                    estimated_money: 25433,
                    shopping_nodes:[
                        {
                            id:'',
                            name: 'Bic Camera · 大型综合电器商场',
                            original_name: '',
                            location: '',
                            my_note: '去购买KK的保温杯、CW姐夫的iPad Pro还有Lupicia的茶叶，手机等等等别的东西',
                            complete_at_date: '2019-12-29'
                        },
                        {
                            id:'',
                            name: '三A百货 · 综合商场',
                            original_name: '',
                            location: '',
                            my_note: '购买HABA的精油购买、资生堂的福袋、购买HABA的精油购买HABA的精油购买HABA的精油购买HABA的精油',
                            complete_at_date: '2019-12-29'
                        },
                        {
                            id:'',
                            name: 'DFS那霸新都心店',
                            original_name: '',
                            location: '',
                            my_note: '购买Coach的包包、各种高级美妆，像是CPB等等等等，其他东西，还有iQos的烟弹',
                            complete_at_date: '2019-12-30'
                        }
                    ],
                    purchase_bills:[
                        {
                            id:'',
                            pay_time: '2019-12-29 10:30:34',
                            original_amount: 4500,
                            original_currency: 'JPY',
                            default_amount: 300,
                            default_currency: 'CNY',
                            bill_images: [
                                {url: ''},
                                {url: ''}
                            ]
                        }
                    ]
                }
            }
        }
        
        status 200

        res.to_json
    end
end

