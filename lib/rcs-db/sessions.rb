#
#  Session Manager, manages all the cookies
#

require_relative 'audit'

# from RCS::Common
require 'rcs-common/trace'

# system
require 'uuidtools'
require 'set'

module RCS
module DB

class SessionManager
  include Singleton
  include RCS::Tracer

  def initialize
    @sessions = {}
  end

  def create(user, level, address, version = nil)
    
    # create a new random cookie
    cookie = UUIDTools::UUID.random_create.to_s
    
    ::Session.create! do |s|
      if level.include? :server
        s[:server] = user
      else
        s.user = user
      end
      s[:level] = level
      s[:cookie] = cookie
      s[:address] = address
      s[:time] = Time.now.getutc.to_i
      s[:version] = version
    end

    get(cookie)
  end

  def get_by_user(username)
    user = ::User.where({name: username}).first
    return nil if user.nil?

    sess = ::Session.where(user: user).first
    return nil if sess.nil?

    get(sess[:cookie])
  end

  def all
    ::Session.not_in(level: ["server"]).all
  end

  def update(cookie)
    return if cookie.nil?

    sess = ::Session.where({cookie: cookie}).first
    return if sess.nil?

    sess[:time] = Time.now.getutc.to_i
    sess.save

    get(cookie)
  end
  
  def get(cookie)
    # use a cache to be faster
    @cookie_cache ||= LRUCache.new(:ttl => 5.minutes)

    sess = @cookie_cache.fetch(cookie)
    return sess if sess

    sess = ::Session.where({cookie: cookie}).first

    @cookie_cache.store(cookie, sess)

    return sess
  end

  def delete(cookie)
    session = ::Session.where({cookie: cookie}).first

    # terminate the websocket connection
    WebSocketManager.instance.destroy(cookie)

    @cookie_cache.delete(cookie)

    # delete the cookie session
    session.destroy unless session.nil?
  end

  def delete_user(user)
    ::Session.destroy_all(user: user)
  end

  def delete_server(user)
    ::Session.destroy_all(server: user)
  end

  def clear_all_servers
    ::Session.in(level: [:server]).destroy_all
  end

  # default timeout is 15 minutes
  # this timeout is calculated from the last session.update (via websocket ping pong)
  def timeout(delta = 900)
    begin
      count = ::Session.all.count
      trace :debug, "Session Manager searching for timed out entries..." if count > 0
      # save the size of the hash before deletion
      size = count
      # search for timed out sessions (don't timeout server sessions)
      ::Session.not_in(level: [:server]).each do |session|

        now = Time.now.getutc.to_i
        if now - session[:time] >= delta

          user = session.user
          # keep the sessions clean of invalid users
          if user.nil?
            session.destroy
            next
          end

          Audit.log :actor => user[:name], :action => 'logout', :user_name => user[:name], :desc => "User '#{user[:name]}' has been logged out for timeout"
          trace :info, "User '#{user[:name]}' has been logged out for timeout"

          PushManager.instance.notify('logout', {rcpt: user[:_id], text: "You were disconnected for timeout"})
          WebSocketManager.instance.destroy(session[:cookie])

          # delete the entry
          session.destroy
        end
      end
      count = ::Session.all.count
      trace :info, "Session Manager timed out #{size - count} sessions" if size - count > 0
    rescue Exception => e
      trace :error, "Cannot perform session timeout: #{e.message}"
    end
  end

  def length
    ::Session.all.count
  end

end #SessionManager

end #DB::
end #RCS::