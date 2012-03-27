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
      timer=nil
       ws.onopen {
         peer_port, peer = Socket.unpack_sockaddr_in(ws.get_peername)
         trace :debug, "WebSocket connection open #{Socket.unpack_sockaddr_in(ws.get_peername)}"

         #timer = EM.add_periodic_timer(1) {
         #  p ["Sent ping", ws.send('hello')]
         #}
         # publish message to the client
         ws.send "Hello Client"
       }

       ws.onpong { |value|
         trace :debug,  "Received pong: #{value}"
       }
       ws.onping { |value|
         trace :debug,  "Received ping: #{value}"
       }

       ws.onclose {
         trace :debug,  "WS Connection closed"
       }

       ws.onmessage { |msg|
         trace :debug,  "Recieved message: #{msg}"
       }

       ws.onerror { |e|
         trace :debug,  "Error: #{e.message}"
       }
    end

  end
end

end #DB::
end #RCS::