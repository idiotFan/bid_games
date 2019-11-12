require 'sequel'
require 'mysql2'
require 'logger'

DB = Sequel.connect(
    adapter: 'mysql2', 
    database: 'flyinggo', 
    user: '', 
    password: '', 
    host: '', 
    port: 3306, 
    loggers: [Logger.new($stdout)])

DB.loggers << Logger.new($stdout)