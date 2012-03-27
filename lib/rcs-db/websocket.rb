#
#  Websocket handler
#


# from RCS::Common
require 'rcs-common/trace'

# system
require 'em-websocket'

module RCS
module DB

class WebSocket
  extend RCS::Tracer

  class << self

    def handle(ws)
      ws.onopen {
        peer_port, peer = Socket.unpack_sockaddr_in(ws.get_peername)
        trace :debug, "WS connection from #{peer}"

        trace :debug, "ws #{ws}"
        # publish message to the client
        ws.send "Hello Client"
      }

      ws.onmessage { |msg|
        trace :debug,  "WS message: #{msg}"
        trace :debug, "ws #{ws}"
      }

      ws.onclose {
        trace :debug,  "WS connection closed"
      }

      ws.onerror { |e|
        trace :debug,  "WS error: #{e.message}"
      }
    end

  end
end

end #DB::
end #RCS::