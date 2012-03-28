#
#  Push manager. Sends event to all the connected clients
#

require_relative 'websocket'

# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

class PushManager
  include Singleton
  include RCS::Tracer

  def notify(type, message={})
    trace :info, "PUSH Event: #{type} #{message}"

    begin
      SessionManager.instance.each_ws(message[:id]) do |ws|
        WebSocketManager.send(ws, type, message)
      end
    rescue Exception => e
      trace :error, "PUSH ERROR: Cannot notify clients #{e.message}"
    end
  end

  def heartbeat
    connected = 0
    begin
      SessionManager.instance.each_ws do |ws|
        WebSocketManager.ping(ws)
        connected = connected + 1
      end
      trace :debug, "PUSH heartbeat: #{connected} clients" if connected > 0
    rescue Exception => e
      trace :error, "PUSH ERROR: Cannot perform clients heartbeat #{e.message}"
    end
  end

end

end #DB::
end #RCS::