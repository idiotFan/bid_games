require 'bcrypt'

class User < Sequel::Model(DB[:user])
  include BCrypt
  # users.password_hash in the database is a :string

  def password
    @password ||= Password.new(password_hash)
  end

  def password=(new_password)
    @password = Password.create(new_password)
    self.password_hash = @password
  end

  def create_new_user(login_id, password)
    #todo: 处理判断login_id的类型，并且加入一些默认的值进去
  end

end