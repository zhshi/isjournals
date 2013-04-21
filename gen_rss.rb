require 'pp'
require 'yaml'
require 'sequel'
require 'rss'

# mysql login conf
sql_conf = {}
File.open("#{ENV["HOME"]}/.mysql_logins/diamond", "r") { |f| sql_conf = YAML.load(f) }
sql_conf["DBName"] = 'JournalMonitor'
# mysql connection
DB = Sequel.mysql2(sql_conf["DBName"], :user => sql_conf["DBID"], :password => sql_conf["DBPW"], :host => sql_conf["DBServer"])
# select mysql dataset
journals = DB[:journals]
articles = DB[:articles]
abstracts = DB[:abstracts]

# rss output file
rss_f = File.open("new_papers.xml", "w")

rss = RSS::Maker.make("atom") do |maker|
  maker.channel.author = "Michael ZS"
  maker.channel.about = "http://info.econst.org"
  maker.channel.updated = Time.now.to_s
  maker.channel.title = "Newly Accepted Papers"

  papers =  articles.select(:idx, :code, :title, :insert_time).order(:insert_time).reverse.limit(100)
  papers.each do |p|
    maker.items.new_item do |item|
      item.link = (journals.where(:code => p[:code]).select(:url).first)[:url]
      item.title = p[:title]
      item.description = (abstracts.where(:idx => p[:idx]).select(:abstract).first)[:abstract]
      item.updated = p[:insert_time].to_s
    end
  end
end

rss_f.puts rss
rss_f.close
