require 'pp'
require 'yaml'
require 'sequel'
require './lib/journal.rb'

# mysql login conf
sql_conf = {}
File.open("#{ENV["HOME"]}/.mysql_logins/diamond", "r") { |f| sql_conf = YAML.load(f) }
sql_conf["DBName"] = 'JournalMonitor'
# mysql connection
DB = Sequel.mysql2(sql_conf["DBName"], :user => sql_conf["DBID"], :password => sql_conf["DBPW"], :host => sql_conf["DBServer"])
# select mysql dataset
journals = DB[:journals]
articles = DB[:articles]
authors = DB[:authors]
abstracts = DB[:abstracts]

journals.select(:code, :publisher, :url).each do |j|
  next if j[:code] != 'misq'
  j = Journal.new(j[:code], j[:publisher].downcase, j[:url])
  j.check(articles, authors, abstracts)
end
