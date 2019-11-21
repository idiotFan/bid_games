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

#开启连表时候的Alias表名和列名自动分割模式，默认不是开启的
Sequel.split_symbols = true

DB.loggers << Logger.new($stdout)