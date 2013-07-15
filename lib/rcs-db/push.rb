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

    item = message.delete(:item)

    if item
      message[:id] = item.id
      message[:user_ids] = item[:user_ids] || []
    end

    # add the message to the queue, this is needed by other processes
    # to communicate (via db) to the real push manager that is connected to consoles
    PushQueue.add(type, message)
  end

  def dispatcher_start
    Thread.new do
      begin
        dispatcher
      rescue Exception => e
        trace :error, "PUSH ERROR: Thread error: #{e.message}"
        trace :fatal, "EXCEPTION: [#{e.class}] " << e.backtrace.join("\n")
        retry
      end
    end
  end

  def each_session_with_web_socket(&block)
    SessionManager.instance.all.each do |session|
      web_socket = WebSocketManager.instance.get_ws_from_cookie(session.cookie)
      # not connected push channel
      next unless web_socket
      yield(session, web_socket)
    end
  end

  def dispatcher
    loop do
      if (queued = PushQueue.get_queued)
        begin
          entry = queued.first
          count = queued.last
          type = entry.type
          message = entry.message

          trace :debug, "#{count} push messages to be processed in queue"

          each_session_with_web_socket do |session, web_socket|
            # if we have specified a recepient, skip all the other online users
            next if message['rcpt'] and session.user.id != message['rcpt']
            # check for accessibility
            user_ids = message.delete('user_ids')
            next if user_ids and !user_ids.include?(session.user.id)
            # send the message
            WebSocketManager.instance.send(web_socket, type, message)

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