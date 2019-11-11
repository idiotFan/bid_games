require 'jwt'

def give_token(user)

end

def auth_login(username, password)
# todo - 实现把所有验证过程都模块化出来
    result = {login_user: nil}

    if username then 
        #找是不是已经存在这个账户
        user = User.where(username: username).first
        if user then 
            if user.password == password then 
                result[:login_user] = user
                result[:message] = '登录成功！'
            else 
                result[:message] = '密码错误！'
            end     
        elsif password then 
            result[:message] = (result[:login_user] = User.new(username: username, password: password, status: 0, deleted: 0, created_at: Time.now, updated_at: Time.now).save) ? '注册账号成功！': '创建账号失败！'
        else 
            result[:message] = '密码不能为空！'
        end
    else
        result[:message] = '账号名/邮箱/手机号不能为空！'
    end  
    return result
end




payload = { password: 'test' }
# password_text = 'example'

# IMPORTANT: set nil as password parameter
token = JWT.encode payload, nil, 'none'

# eyJhbGciOiJub25lIn0.eyJkYXRhIjoidGVzdCJ9.
puts token

# Set password to nil and validation to false otherwise this won't work
decoded_token = JWT.decode token, nil, false

# Array
# [
#   {"data"=>"test"}, # payload
#   {"alg"=>"none"} # header
# ]
puts decoded_token