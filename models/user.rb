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

end