def update_token(user)
    # REVIEW 这个应该写到Model层
    # 加密原码
    payload = { user_id: user.id, time: user.created_at}
    current_token = UserToken.where(user_id: user.id, deleted: 0).first
    if current_token then 
        current_token.update(:token => (JWT.encode payload, nil, 'none')).save
    else 
        token = JWT.encode payload, nil, 'none'
        current_token = UserToken.new(user_id: user.id, token: token).save
    end

    return current_token.token
end

def auth_login(username, password)
    result = {login_user: nil}

    if username then 
        #找是不是已经存在这个账户
        user = User.where(username: username).first
        if user then 
            if user.password == password then 
                result[:login_user] = user
                result[:message] = '登录成功！'
                result[:token] = update_token(user)
            else 
                result[:message] = '密码错误！'
            end     
        elsif password then 
            result[:message] = (result[:login_user] = User.new(username: username, password: password, status: 0, deleted: 0, created_at: Time.now, updated_at: Time.now).save) ? '注册账号成功！': '创建账号失败！'
            result[:token] = update_token(result[:login_user])
        else 
            result[:message] = '密码不能为空！'
        end
    else
        result[:message] = '账号名/邮箱/手机号不能为空！'
    end  
    return result
end


def verify_token(token)
    result = {verify_login_user: nil}

    @token = UserToken.where(token: token).first

    if @token then 
        #找是不是已经存在这个Token，这里没有做时间自动过期的逻辑
        result[:verify_login_user] = @token.user_id
        result[:message] = 'Token有效，无需登录'
    else
        result[:message] = '登录已经失效！请重新登录'
    end  
    return result
end



