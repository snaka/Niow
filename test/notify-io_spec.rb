require '../lib/notify-io'

# use Double Ruby for mock/stub framework.
Spec::Runner.configure do |conf|
  conf.mock_with :rr
end

# describe GNTP behavior
describe NotifyIO do

  before do
    ENV['http_proxy'] = 'http://user:pass@address.to.proxy:8080'
  end

  it "can extract authenticate informatin from environment variable" do
    notify_io = NotifyIO.new
    notify_io.should_not nil

    proxy = notify_io.get_proxy
    proxy.host == 'address.to.proxy'
    proxy.port == 8080
    proxy.user == 'user'
    proxy.password == 'pass'
  end

end
