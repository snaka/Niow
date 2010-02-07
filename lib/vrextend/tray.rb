#
# system tray stuff
#

module VRTrayiconFeasible

  # Overrides default message dispatcher
  def self__vr_traynotify(wparam,lparam)
    case lparam
    when WMsg::WM_LBUTTONDBLCLK
      selfmsg_dispatching("traylbuttondblclk",wparam)
    when WMsg::WM_RBUTTONUP
      selfmsg_dispatching("trayrbuttonup",wparam)
    end
  end
end
