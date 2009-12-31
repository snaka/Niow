#
# Notify.io client for windows
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

require 'yaml/store'
require 'kconv'
require 'Win32API'

require 'vr/vruby'
require 'vr/vrlayout'
require 'vr/vrcontrol'
require 'vr/vrtray'
require 'vr/vrdialog'

require 'rubygems'
require 'ruby_gntp'

require 'notify-io'
require 'notify-io/util'

$exepath = File.dirname(File.expand_path(__FILE__))

ExtractIcon = Win32API.new("shell32", "ExtractIcon", "LPI", "L")
$mini_icon = ExtractIcon.call(0, "#{$exepath}/notify.ico", 0)

Signal.trap(:INT) {
  puts "exit..."
  exit
}


# log display area
class LogArea < VRText

  def put_msg(text)
    self.text = self.text +
      "---------- #{Time.now} ----------\n" +
      text.tosjis +
      "\n"
    self.scrollTo(self.countLines, 0)
  end

  def put_line(line)
    self.text = self.text + line + "\n"
  end
      
end


# input dialog
module InputDialog

  def construct
    move 200, 200, 315, 115 
    self.caption = "Please input.. "
    addControl(VRStatic, "label", label_text, 5, 5, 300, 25)
    addControl(VREdit, "input_edit", "", 5, 25, 300, 25)
    addControl(VRButton, "close_button", "OK", 100, 50, 100, 25)
  end

  def close_button_clicked
    close(@input_edit.text)
  end

  def caption_text
    ""  # override in subclass
  end

end

# account input dialog
module AccountInputDialog
  include InputDialog
  def label_text; "Please input your google account(email)"; end
end

# password input dialog
module PasswordInputDialog
  include InputDialog
  def label_text; "Plese input your password for google account"; end
end


# main form
class NotifyClient < VRForm

  include VRMenuUseable
  include VRTrayiconFeasible
  include VRGridLayoutManager

  def construct

    self.caption = "Notify.io client for windows"
    setDimension(10, 10)
    addControl(LogArea, "log_area", "", 0, 0, 10, 9, WStyle::WS_VSCROLL)
    addControl(VRButton, "close_button", "Minimize in tasktray", 0, 9, 10, 1)
    @log_area.readonly = true

    # register growl
    @growl = GNTP.new("Notify.io")
    @growl.register(
      :app_icon => "file://#{$exepath}/notify-io.png",
      :notifications => [ :name => "notify", :enabled => true ]
    )

    @growl.notify(
      :name     => "notify",
      :title    => "Notify.io client for Windows",
      :text     => "Now starting...",
      :icon     => "file://#{$exepath}/notify-io.png" 
    )

    # tray menu
    @traymenu = newPopupMenu
    @traymenu.set([
      ["Open window", "restore"],
      ["Exit", "exit"]
    ])

    polling

    set_form_icon

    # to system tray after n sec.
    Thread.new(@log_area) do |log|
      log.put_msg("Going to tasktray after 5 seconds.")
      sleep 5
      close_button_clicked
    end
  end

  # --- event handlers 

  def close_button_clicked
    self.hide
    create_trayicon($mini_icon)
  end

  def self_trayrbuttonup(iconid)
    showPopup @traymenu
  end

  # menu handlers
  def restore_clicked
    self.show
    delete_trayicon
  end

  def exit_clicked
    delete_trayicon
    self.close
  end

  # --- other methods

  # waiting for api response
  def polling
    Thread.new(@growl, @log_area) do |g, log|

      storage = YAML::Store.new("#{$exepath}/key.yaml")
      notify_io = NotifyIO.new

      notify_io.account do
        account = nil
        storage.transaction do
          unless storage[:account]
            user_input = VRLocalScreen.modalform(nil, nil, AccountInputDialog)
            abort unless user_input

            storage[:account] = user_input
          end
          account = storage[:account]
        end

        account
      end

      notify_io.api_key do |account|
        api_key = nil
        storage.transaction do
          unless storage[:api_key]
            passwd = VRLocalScreen.modalform(nil, nil, PasswordInputDialog)
            abort unless passwd

            begin
              storage[:api_key] = get_apikey(account, passwd)
            rescue
              abort
            end
          end
          api_key = storage[:api_key]
        end

        log.put_line "account : #{account}"
        log.put_line "api_key : #{'*' * api_key.size}"

        api_key
      end

      notify_io.start do |notify|
        log.put_msg(notify.to_s)
        g.notify(
          :name   => "notify", 
          :title  => notify["title"], 
          :text   => notify["text"],
          :icon   => notify["icon"]
        )
      end
    end
  end

  def set_form_icon
    SMSG::sendMessage( self.hWnd, 
                       0x80,         # WM_SETICON 
                       0,            # 0: ICON_SMALL / 1: ICON_BIG
                       $mini_icon ) 
  end

end

VRLocalScreen.start(NotifyClient, 150, 150, 600, 400)

