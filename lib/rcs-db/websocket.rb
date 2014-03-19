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
  include Singleton
  include RCS::Tracer

  def initialize
    @sessions = {}
  end

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
      trace :debug,  "[#{ws.object_id}] WS error: #{e.backtrace}"
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

    user = session.user

    # grant the access to the client
    ws.send({type: 'auth', result: 'granted', time: Time.now.getutc.to_i}.to_json)

    if user.password_expiring?
      ws.send({type: 'message', from: 'Password manager', text: "Your password will expire in #{user.password_days_left} day(s), please change it. Passwords expire every 3 months."}.to_json)
    end

    # save the websocket handle in the session for later use in push messages
    @sessions[msg['cookie']] = ws
  end

  def onping(ws, msg)
    trace :debug, "[#{ws.object_id}] WS ping"
    pong(ws)
  end

  def onpong(ws, msg)
    # keep the session valid by updating its last contact time
    session = SessionManager.instance.update(get_cookie_from_ws(ws))
    trace :debug, "[#{ws.object_id}] WS pong: #{session[:address]}"
  end

  def ping(ws)
    ws.send({type: 'ping'}.to_json)
  end

  def ping_all
    @sessions.values.each do |ws|
      ping(ws)
    end
    return @sessions.size
  end

  def pong(ws)
    ws.send({type: 'pong'}.to_json)
  end

  def close(ws)
    trace :debug,  "[#{ws.object_id}] WS connection closed"
    @sessions.delete get_cookie_from_ws(ws)
  end

  def send(ws, type, message={})
    msg = {type: type}
    msg.merge! message
    ws.send(msg.to_json)
  end

  def destroy(cookie)
    return if @sessions[cookie].nil?
    @sessions[cookie].close_websocket
    @sessions.delete cookie
  end

  def get_cookie_from_ws(ws)
    @sessions.each_pair do |cookie, w|
      if w == ws
        return cookie
      end
    end
    return nil
  end

  def get_ws_from_cookie(cookie)
    @sessions[cookie]
  end

end

end #DB::
end #RCS::