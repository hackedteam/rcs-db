#
#  Websocket handler
#


# from RCS::Common
require 'rcs-common/trace'

# system
require 'em-websocket'

module RCS
module DB

class WebSocketManager
  extend RCS::Tracer

  class << self

    def handle(ws)
      ws.onopen {
        peer_port, peer = Socket.unpack_sockaddr_in(ws.get_peername)
        trace :debug, "[#{ws.object_id}] WS connection from #{peer}:#{peer_port}"
      }

      ws.onmessage { |msg|
        # decode the message
        message = JSON.parse(msg)

        # handle the request
        case message['type']
          when 'auth'
            auth(ws, message)
          when 'ping'
            onping(ws, message)
          when 'pong'
            onpong(ws, message)
          else
            trace :debug,  "[#{ws.object_id}] WS message: #{msg}"
        end
      }

      ws.onclose {
        close(ws)
      }

      ws.onerror { |e|
        trace :debug,  "[#{ws.object_id}] WS error: #{e.message}"
      }
    end

    def auth(ws, msg)
      trace :debug, "[#{ws.object_id}] WS auth #{msg['cookie']}"
      session = SessionManager.instance.get msg['cookie']

      # deny access if the user is not already authenticated
      if session.nil?
        trace :error, "[#{ws.object_id}] WS auth INVALID #{msg['cookie']}"
        ws.send({type: 'auth', result: 'denied'}.to_json)
        ws.close_websocket
        return
      end

      # grant the access to the client
      ws.send({type: 'auth', result: 'granted'}.to_json)

      # save the websocket handle in the session for later use in push messages
      session[:ws] = ws
    end

    def onping(ws, msg)
      trace :debug, "[#{ws.object_id}] WS ping"
      pong(ws)
    end

    def onpong(ws, msg)
      trace :debug, "[#{ws.object_id}] WS pong"

      # keep the main session alive
      session = SessionManager.instance.get_by_ws ws
      session[:time] = Time.now.getutc.to_i
    end

    def ping(ws)
      ws.send({type: 'ping'}.to_json)
    end

    def pong(ws)
      ws.send({type: 'pong'}.to_json)
    end

    def close(ws)
      trace :debug,  "[#{ws.object_id}] WS connection closed"
      session = SessionManager.instance.get_by_ws ws
      # release the handler in the session
      session[:ws] = nil
    end

    def send(ws, type, message={})
      msg = {type: type}
      msg.merge! message
      ws.send(msg.to_json)
    end
  end
end

end #DB::
end #RCS::