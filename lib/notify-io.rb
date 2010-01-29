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

  def get_proxy
    URI.parse(ENV['http_proxy'] || '')
  end

  #
  # Start main loop
  #
  def start(target_urls)

    if !target_urls or target_urls.size == 0
      raise "target_url is nil or empty"
    end
    
    p target_urls if $DEBUG

    target_urls.each do |target|
      puts "*** target: #{target}" if $DEBUG

      Thread.new(URI.parse(target)) do |uri|
        proxy = get_proxy
        puts "proxy host: #{proxy.host} / port: #{proxy.port} / user: #{proxy.user} / pass: #{proxy.password}" if $DEBUG

        # Main loop
        while true
          begin
            puts "Waiting for response #{target} ..."  if $DEBUG
            Net::HTTP::Proxy(proxy.host, proxy.port, proxy.user, proxy.password).start(uri.host) {|http|
              http.read_timeout = 60 * 15 
              puts "timeout after #{http.read_timeout} sec."  if $DEBUG

              http.get(uri.path) {|str|
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
        end # Main loop

      end # Thread

    end # target_urls
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

# vim: sw=2 ts=2 et fdm=marker
