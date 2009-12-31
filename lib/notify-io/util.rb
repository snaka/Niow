#
# utility for Notify.io site navigation
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

require 'rubygems'
require 'mechanize'

def get_apikey(account, passwd)
  hash = Digest::MD5.hexdigest(account)
  agent = WWW::Mechanize.new

  # go to login page & submit
  page = agent.get("http://www.notify.io/dashboard/settings")
  page.parser.encoding = 'utf-8'
  login_form = page.forms[0]
  login_form.Email = account
  login_form.Passwd = passwd
  page = agent.submit(login_form)

  # verify uri
  unless page.uri.to_s =~ /^https:\/\/www\.google\.com\/accounts\/CheckCookie/
    raise "Authentication failed. Or invalid page respond."
  end

  # follow redirect
  dest_uri = page.meta[0].uri
  page = agent.get(dest_uri)

  # verify uri
  unless page.uri.to_s =~ /^http:\/\/www\.notify\.io\/dashboard\/settings/
    raise "Invalid page respond."
  end

  # get apikey
  credentials = page.search("//div[@id='panel']/p/text()")
  matched = /API key:\s*(.*)/.match(credentials.to_s)
  exit "Failed to get apikey" unless matched.size > 0
  apikey = matched[1]

  apikey
end

if __FILE__ == $0
  # test
  account = ARGV[0]
  passwd  = ARGV[1]
  puts get_apikey(account, passwd)
end

