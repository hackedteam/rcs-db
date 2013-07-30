require 'rcs-common/trace'
require_relative 'websocket'

# Push manager.
# Sends event to all the connected clients.
module RCS
  module DB
    class PushManager
      include Singleton
      include RCS::Tracer

      attr_accessor :suppressed

      def initialize
        self.suppressed = {}
        @suppression_window = 1.0
      end

      def notify(type, message={})
        trace :debug, "PUSH Event: #{type} #{message}"

        if (item = message.delete(:item))
          message[:id] = item.id
          message[:user_ids] = item[:user_ids] || []
        end

        PushQueue.add(type, message)
      end

      def run
        loop_on { dispatch_or_wait }
      rescue Exception => e
        trace :error, "PUSH ERROR: Thread error: #{e.message}"
        trace :fatal, "EXCEPTION: [#{e.class}] " << e.backtrace.join("\n")
        retry
      end

      def loop_on(&block)
        loop(&block)
      end

      def each_session_with_web_socket(&block)
        SessionManager.instance.all.each do |session|
          web_socket = WebSocketManager.instance.get_ws_from_cookie(session.cookie)
          # not connected push channel
          next unless web_socket
          yield(session, web_socket)
        end
      end

      def pop
        type, message = suppressed.delete(suppressed.keys.first)
        return [type, message] if type

        queued = nil

        loop_on do
          queued = PushQueue.get_queued
          return unless queued
          type, message = queued[0].type, queued[0].message
          suppress?(message) ? suppress(type, message) : break
        end

        trace :debug, "#{queued[1]} push messages to be processed in queue"
        [type, message]
      end

      def wait_a_moment
        sleep 1
      end

      def send(web_socket, type, message)
        WebSocketManager.instance.send(web_socket, type, message)
        trace :debug, "PUSH Event (sent): #{type} #{message}"
      end

      def suppress(type, message)
        key = message['suppress']['key']
        suppressed[key] = [type, message]
      end

      def suppress?(message)
        hash = message['suppress']
        return false unless hash
        return false unless hash['key'] and hash['start']
        Time.now.getutc.to_f - hash['start'] <= @suppression_window
      end

      def dispatch(type, message)
        each_session_with_web_socket do |session, web_socket|
          usr_id = session.user.id
          # if we have specified a recepient(s), skip all the other online users
          next if message['rcpt'] and usr_id != message['rcpt']
          next if message['rcpts'] and !message['rcpts'].include?(usr_id)
          # check for accessibility
          user_ids = message.delete('user_ids')
          next if user_ids and !user_ids.include?(usr_id)
          # does not send suppress hash to the clients
          message.delete('suppress')
          # send the message
          send(web_socket, type, message)
        end
      end

      def dispatch_or_wait
        type, message = pop

        if type
          dispatch(type, message)
        else
          wait_a_moment
        end
      end

      def heartbeat
        connected = WebSocketManager.instance.ping_all
        trace :debug, "PUSH heartbeat: #{connected} clients" if connected > 0
      rescue Exception => e
        trace :error, "PUSH ERROR: Cannot perform clients heartbeat #{e.message}"
      end
    end
  end
end
