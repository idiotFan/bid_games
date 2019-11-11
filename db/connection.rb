require 'sequel'
require 'mysql2'
require 'logger'

DB = Sequel.connect(
    adapter: 'mysql2', 
    database: 'flyinggo', 
    user: 'root', 
    password: '', 
    host: 'localhost', 
    port: 3306, 
    loggers: [Logger.new($stdout)])

DB.loggers << Logger.new($stdout)

###### 如果表有缺失，会自动建表 ######

# 游戏局记录表
DB.create_table? :bid_game do 
    primary_key :id
    String :name, null: true
    String :game_info, null: false
    String :type, null: false, comment: "1 单独最小价格；"
    Float :single_bid_fee, null: false #下注一次的单价
    Int :maximum_player_num, null: false #最多参与人数，到达最多参与人数之后会自动把次局游戏更新为结束
    Int :status, default: 0, null: false
    String :opened_by
    Boolean :deleted, default: 0
    DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
end

# 单独最小价格游戏进行记录表
DB.create_table? :single_min_game_submittion do 
    primary_key :id 
    String :bid_game_id, null: false
    Int :submitted_value, null: false
    String :submitted_by, null: false
    Boolean :deleted, default: 0
    DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
end

# demo投票选项表
DB.create_table? :choice do 
    primary_key :id
    String :key, null: false
    String :value, null: false
    Boolean :deleted, default: 0
    DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
end

# demo投票记录表
DB.create_table? :vote do 
    primary_key :id
    String :voted_by, null: false
    String :voted_key, null: false
    Boolean :deleted, default: 0
    DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
end

#用户表
DB.create_table? :user do 
    primary_key :id
    String :nickname
    String :username
    String :password_hash
    String :mobile_phone
    Int :status
    String :mp_openid
    String :mp_union_id
    Boolean :deleted, default: 0
    DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
end

#用户登录token表
DB.create_table? :user_token do 
    primary_key :id
    String :user_id
    String :token
    Boolean :deleted, default: 0
    DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
end

#卖家表
DB.create_table? :seller do 
    primary_key :id
    Smallint :role_type
    Int :user_id
    Int :status
    Boolean :deleted, default: 0
    DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
end

#店铺表
DB.create_table? :shop do 
    primary_key :id
    Int :owner_seller
    String :title_image
    String :main_color
    String :name
    Smallint :status
    Boolean :deleted, default: 0
    DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
end

#SPU商品表 - Item
DB.create_table? :item_spu do 
    primary_key :id
    String :title
    String :info
    Int :status
    Boolean :deleted, default: 0
    DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
end

#SKU 关联商品SPU表
DB.create_table? :sku do 
    primary_key :id
    String :title
    String :info
    Int :type_property_id
    Int :belongs_to_spu    
    Int :shop_id
    Int :status
    Boolean :deleted, default: 0
    DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
end

#SKU 属性对应表
DB.create_table? :sku_property do 
    primary_key :id
    String :tag_value
    String :tag_text
    Int :status
    Boolean :deleted, default: 0
    DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
end

# 买家预订表
DB.create_table? :user_order do 
    primary_key :id
    Float :paid_amount
    Int :user_id
    Int :status
    Boolean :deleted, default: 0
    DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
end

# 买家订单关联商品表
DB.create_table? :user_order_item do 
    primary_key :id
    Int :order_id
    Int :sku_id
    Int :sku_count
    Int :status
    Boolean :deleted, default: 0
    DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
end

# 卖家采购记录表
DB.create_table? :seller_purchase do 
    primary_key :id
    Int :user_id
    String :place
    String :place_type
    String :place_location
    String :invoice_images
    String :paid_original_amount
    String :paid_currency
    String :discount_amount
    Float :exchange_rate
    String :pay_channel
    Int :status
    Boolean :deleted, default: 0
    DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
end

# 卖家采购订单关联商品表
DB.create_table? :seller_purchase_sku do 
    primary_key :id
    Int :purchase_id
    Int :sku_id
    Int :sku_count
    Int :status
    Boolean :deleted, default: 0
    DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
end