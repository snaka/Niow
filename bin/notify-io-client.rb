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

require 'kconv'
require 'Win32API'
require 'Win32/registry'

require 'vr/vruby'
require 'vr/vrlayout'
require 'vr/vrcontrol'
require 'vr/vrtray'
require 'vr/vrdialog'

require 'rubygems'
require 'ruby_gntp'

require 'notify-io'

$notify_io = 'http://www.notify.io'

def to_std(path)
  path.split(File::ALT_SEPARATOR).join(File::SEPARATOR)
end

$exepath =  if $Exerb then
              File.dirname(to_std(ExerbRuntime.filepath())) 
            else
              File.dirname(File.expand_path(__FILE__))
            end
$exename = $Exerb ? ExerbRuntime.filename() : __FILE__


ShellExecute = Win32API.new("shell32", "ShellExecute", "LPPPPI", "L")
ExtractIcon  = Win32API.new("shell32", "ExtractIcon", "LPI", "L")
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

# main form
class NotifyClient < VRForm

  include VRMenuUseable
  include VRTrayiconFeasible
  include VRGridLayoutManager

  def initialize
    # register application
    Win32::Registry::HKEY_CURRENT_USER.create('Software\Classes\.ListenURL') do |reg|
      if reg.created?
        reg.write_s nil, "Notify_io"
      end
    end

    Win32::Registry::HKEY_CURRENT_USER.create('Software\Classes\Notify_io') do |reg|
      if reg.created?
        reg.write_s nil, "Notify.io client"
        reg.create('shell\register\command') do |command|
          command.write_s nil, "\"#{to_win_path($exepath)}\\#{$exename}\" \"%1\""
        end
        messageBox "The application installation succeeded."
      end
    end

    # register to growl
    @growl = GNTP.new("Notify.io")
    @growl.register(
      :app_icon => "file://#{$exepath}/notify-io.png",
      :notifications => [ :name => "notify", :enabled => true ]
    )

    store_config if ARGV[0]

    # get targets
    unless File.exist?($config_file)
      messageBox "ListenURL file has not installed.\nPlease download and install ListenURL file from your Notify.io 'Outlet' page."
      ShellExecute.call(self.hWnd, "open", "#{$notify_io}/outlets", 0, 0, 1)
      exit -1
    end

  end

  def to_win_path(path)
    path.split('/').join(File::ALT_SEPARATOR)
  end

  def construct

    self.caption = "Notify.io client for windows"
    setDimension(10, 10)
    addControl(LogArea, "log_area", "", 0, 0, 10, 9, WStyle::WS_VSCROLL)
    addControl(VRButton, "close_button", "Minimize in tasktray", 0, 9, 10, 1)
    @log_area.readonly = true

    # set tray menu
    @traymenu = newPopupMenu
    @traymenu.set([
      ["Open window", "restore"],
      ["History", "open_history"],
      ["Settings", "open_settings"],
      ["Exit", "exit"]
    ])

    polling

    set_form_icon

    # to system tray after n sec.
    Thread.new(@log_area) do |log|
      log.put_msg("This window is stored in the task tray, 5 seconds after.")
      sleep 5
      close_button_clicked
    end

    notify "Now starting..."
  end

  # --- other methods

  $config_file = File.expand_path("~/.Niow")

  # store configuration info
  def store_config
    File.open($config_file, "w") do |file|
      ARGF.each do |line|
        file.puts line
      end 
    end
    notify "ListenURL file has installed successfully."
  end

  # notify
  def notify(msg)
    @growl.notify(
      :name     => "notify",
      :title    => "Notify.io client for Windows",
      :text     => msg,
      :icon     => "file://#{$exepath}/notify-io.png" 
    )
  end

  # waiting for api response
  def polling

    notify_io = NotifyIO.new
    target_urls = []

    begin
      target_urls = File.open($config_file, "r").readlines
    rescue
      messageBox "Can't open #{$config_file}"
      exit -1
    end

    notify_io.start(target_urls) do |notify|
      @log_area.put_msg(notify.to_s)
      @growl.notify(
        :name   => "notify", 
        :title  => notify["title"], 
        :text   => notify["text"],
        :icon   => notify["icon"]
      )
    end

  end

  def set_form_icon
    SMSG::sendMessage( self.hWnd, 
                       0x80,         # WM_SETICON 
                       0,            # 0: ICON_SMALL / 1: ICON_BIG
                       $mini_icon ) 
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

  def open_history_clicked
    ShellExecute.call(self.hWnd, "open", "#{$notify_io}/history", 0, 0, 1)
    @log_area.put_msg("Open history page...")
  end

  def open_settings_clicked
    ShellExecute.call(self.hWnd, "open", "#{$notify_io}/settings", 0, 0, 1)
    @log_area.put_msg("Open settings page...")
  end

  def exit_clicked
    delete_trayicon
    self.close
  end

end

VRLocalScreen.start(NotifyClient, 150, 150, 600, 400)

# vim: ts=2 sw=2 et fdm=marker
