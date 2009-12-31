#
# Notify.io client
#

# LICENSE BLOCK {{{
=begin

The MIT License

Copyright (c) 2010 snaka <snaka.gml AT gmail.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

=end
# }}}


require 'digest/md5'
require 'net/http'

require 'rubygems'
require 'json/pure'

module NotifyDumper
  def to_s
    buf = ""
    buf << "title : #{self['title']}\n" if self['title']
    buf << "text  : #{self['text']}\n"  if self['text']
    buf << "icon  : #{self['icon']}\n"  if self['icon']
    buf
  end
end

class NotifyIO

  def account=(acc)
    @account = acc
  end
  
  def account(&block)
    if block_given?
      return @account = block
    end
    return @account.call 
  end

  def api_key=(key)
    @api_key = key
  end

  def api_key(&proc)
    if proc
      @api_key = proc
    else
      if @api_key.respond_to?(:call)
        return @api_key.call(account)
      end
      return @api_key
    end
  end

  def user_hash
    acc = nil
    if @account.respond_to?(:call)
      acc = @account.call
    else
      acc = @account
    end
    Digest::MD5.hexdigest(acc) || ''
  end

  def get_proxy
    (ENV["http_proxy"] || "").sub(/http:\/\//, "").split(/[:\/]/)
  end

  #
  # Start main loop
  #
  def start

    url = "/v1/listen/#{user_hash}?api_key=#{api_key}"

    proxy_host, proxy_port = get_proxy
    puts "proxy host: #{proxy_host} / port: #{proxy_port}" if $DEBUG

    # Main loop
    while true
      begin
        puts "Waiting for response..."  if $DEBUG
        Net::HTTP::Proxy(proxy_host, proxy_port).start('api.notify.io') {|http|
          http.read_timeout = 60 * 30 
          puts "timeout after #{http.read_timeout} sec."  if $DEBUG
          http.get(url) {|str|
            p str   if $DEBUG
            begin
              notify = JSON.parse(str)
              notify.extend(NotifyDumper)
              yield notify
            rescue
              puts "Parsing failed"  if $DEBUG
            end
          }
        }
      rescue Timeout::Error => ex
        # do nothing
        puts "Timeout and retry ..."  if $DEBUG
      end
    end
  end
end
 
### self test
if __FILE__ == $0
  # intrrupt handler
  Signal.trap(:INT) {
    puts "exit ..."
    exit
  }

  notify_io = NotifyIO.new
  notify_io.account = ARGV[0]
  notify_io.api_key = ARGV[1]

  notify_io.start do |notify|
    p notify  
  end

end

