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

  def create(user, level, address, accessible = [], console_version = nil)
    
    # create a new random cookie
    #cookie = SecureRandom.random_bytes(8).unpack('H*').first
    cookie = UUIDTools::UUID.random_create.to_s
    
    ::Session.create!({:user => []}) do |s|
      if level.include? :server
        s[:user] = [ user ]
      else
        s[:user] = [ user[:_id] ]
      end
      s[:level] = level
      s[:cookie] = cookie
      s[:address] = address
      s[:time] = Time.now.getutc.to_i
      s[:accessible] = accessible
      s[:console_version] = console_version
    end

    get(cookie)
  end

  def get_by_user(username)
    user = ::User.where({name: username}).first
    return nil if user.nil?

    sess = ::Session.where({user: [ user[:_id] ]}).first
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
    sess = ::Session.where({cookie: cookie}).first
    return nil if sess.nil?

    # create a fake object with a real user reference
    session = {}
    if sess[:level].include? :server
      session[:user] = nil
    else
      session[:user] = ::User.find(sess[:user]).first
    end
    session[:level] = sess[:level]
    session[:address] = sess[:address]
    session[:cookie] = sess[:cookie]
    session[:time] = sess[:time]
    session[:accessible] = sess[:accessible]
    session[:console_version] = sess[:console_version]

    return session
  end

  def get_session(cookie)
    ::Session.where({cookie: cookie}).first
  end

  def delete(cookie)
    session = ::Session.where({cookie: cookie}).first

    # terminate the websocket connection
    WebSocketManager.instance.destroy(cookie)

    # delete the cookie session
    session.destroy
  end

  def delete_user(user)
    ::Session.destroy_all(conditions: {user: [ user ]})
  end

  # default timeout is 15 minutes
  # this timeout is calculated from the last time the cookie was checked
  def timeout(delta = 900)
    begin
      count = ::Session.all.count
      trace :debug, "Session Manager searching for timed out entries..." if count > 0
      # save the size of the hash before deletion
      size = count
      # search for timed out sessions
      ::Session.all.each do |session|

        now = Time.now.getutc.to_i
        if now - session[:time] >= delta

          # don't log timeout for the server
          unless session[:level].include? :server

            user = User.where({_id: session[:user].first}).first
            # keep the sessions clean of invalid users
            if user.nil?
              session.destroy
              next
            end

            Audit.log :actor => user[:name], :action => 'logout', :user_name => user[:name], :desc => "User '#{user[:name]}' has been logged out for timeout"
            trace :info, "User '#{user[:name]}' has been logged out for timeout"

            PushManager.instance.notify('logout', {rcpt: user[:_id], text: "You were disconnected for timeout"})
            WebSocketManager.instance.destroy(session[:cookie])
          end

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

  def get_accessible(user)
    
    # the list of accessible Items
    accessible = Set.new

    # search all the groups which the user belongs to
    ::Group.any_in({_id: user.group_ids}).each do |group|
      # add all the accessible operations
      accessible += group.item_ids
    end

    # for each operation search the Items belonging to it
    accessible.dup.each do |operation|
      # it is enough to search in the _path to check the membership
      ::Item.any_in({path: [operation]}).each do |item|
        accessible << item[:_id]
      end
      ::Entity.any_in({path: [operation]}).each do |item|
        accessible << item[:_id]
      end
    end

    trace :debug, "Accessible list for #{user.name} has #{accessible.size} elements"
    #trace :warn, "Accessible list for #{user.name} has #{accessible.size} elements" if accessible.size >= 100

    return accessible.to_a
  end

  def add_accessible_item(previous, item)
    # add to all the active session the new agent
    # if the previous item is in the accessible list, we are sure that even
    # the new item will be in the list
    ::Session.all.each do |sess|
      if sess[:accessible].include? previous[:_id]
        sess[:accessible] = sess[:accessible] + [ item[:_id] ]
        sess.save
      end
    end
  end

  def add_accessible(session, id)
    # persist it in the db
    ::Session.where({cookie: session[:cookie]}).each do |sess|
      sess[:accessible] = sess[:accessible] + [ id ]
      sess.save
    end
  end

  def rebuild_all_accessible
    # create a new thread to be fast returning from this method
    Thread.new do
      begin
        trace :debug, "Rebuilding accessible list..."
        ::Session.all.each do |sess|
          # skip authenticated collector
          next if sess[:level].include? :server

          user = ::User.find(sess[:user].first)
          sess[:accessible] = get_accessible(user)
          sess.save
          trace :debug, "Accessible for #{user[:name]} rebuilt"
        end
      rescue Exception => e
        trace :error, "Rebuilding accessible list failed: #{e.message}"
      ensure
        Thread.exit
      end
    end
  end

end #SessionManager

end #DB::
end #RCS::