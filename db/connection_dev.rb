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

Sequel.split_symbols = true

DB.loggers << Logger.new($stdout)