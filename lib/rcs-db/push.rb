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
    trace :debug, "PUSH Event: #{type} #{message}"

    # add the message to the queue, this is needed by other processes
    # to communicate (via db) to the real push manager that is connected to consoles
    PushQueue.add(type, message)
  end

  def dispatcher

    loop do
      if (queued = PushQueue.get_queued)
        begin
          entry = queued.first
          type = entry.type
          message = entry.message

          SessionManager.instance.all.each do |session|
            ws = WebSocketManager.instance.get_ws_from_cookie session[:cookie]
            # not connected push channel
            next if ws.nil?

            # we have specified a specific user, skip all the others
            next if message[:rcpt] != nil and session.user[:_id] != message[:rcpt]

            # check for accessibility, if we pass and id, we only want the ws that can access that id
            item = ::Item.where(_id: message[:id]).in(user_ids: [session.user[:_id]]).first
            item = ::Entity.where(_id: message[:id]).in(user_ids: [session.user[:_id]]).first if item.nil?
            next if message[:id] != nil and item.nil?

            # send the message
            WebSocketManager.instance.send(ws, type, message)

            trace :debug, "PUSH Event (sent): #{type} #{message}"
          end

        rescue Exception => e
          trace :error, "PUSH ERROR: Cannot notify clients #{e.message}"
        end

      else
        # Nothing to do, waiting...
        sleep 1
      end
    end
  end

  def heartbeat
    connected = 0
    begin
      connected = WebSocketManager.instance.ping_all
      trace :debug, "PUSH heartbeat: #{connected} clients" if connected > 0
    rescue Exception => e
      trace :error, "PUSH ERROR: Cannot perform clients heartbeat #{e.message}"
    end
  end

end

end #DB::
end #RCS::