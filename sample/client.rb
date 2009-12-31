require 'yaml/store'

require 'rubygems'
require 'ruby_gntp'

require 'get_apikey'
require 'notify-io'

# intrrupt handler
Signal.trap(:INT) {
  puts "exit ..."
  exit
}

db = YAML::Store.new("key.yaml")

notify_io = NotifyIO.new

notify_io.account do
  account = nil
  db.transaction do
    account = db[:account]
    unless account
      print "input your user name: "
      db[:account] = account = gets.chomp!
    end
  end
  account
end

notify_io.api_key do |account|
  api_key = nil
  db.transaction do
    api_key = db[:api_key]
    unless api_key
      print "input your passwd: "
      passwd = gets.chomp!
      db[:api_key] = api_key = get_apikey(account, passwd)
      puts "apikey : #{api_key}"
    end
  end
  api_key
end


notify_io.start do |notify|
  GNTP.notify(
    :app_name => "notify.io", 
    :title => notify["title"], 
    :text => notify["text"],
    :icon => notify["icon"]
  )
end

