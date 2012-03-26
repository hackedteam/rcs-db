#
#  Session Manager, manages all the cookies
#

require_relative 'audit'

# from RCS::Common
require 'rcs-common/trace'

# system
require 'uuidtools'

module RCS
module DB

class SessionManager
  include Singleton
  include RCS::Tracer

  def initialize
    @sessions = {}
  end

  def create(user, level, address, accessible = [])
    
    # create a new random cookie
    #cookie = SecureRandom.random_bytes(8).unpack('H*').first
    cookie = UUIDTools::UUID.random_create.to_s
    
    # store the sessions
    @sessions[cookie] = {:user => user,
                         :level => level,
                         :cookie => cookie,
                         :address => address,
                         :time => Time.now.getutc.to_i,
                         :accessible => accessible}

    return @sessions[cookie]
  end

  def get_by_user(user)
    @sessions.each_pair do |cookie, sess|
      if sess[:user][:name] == user
        return sess
      end
    end
    return nil
  end

  def all
    list = []
    @sessions.each_pair do |cookie, sess|
      # do not include server accounts
      s = sess.clone
      s.delete :accessible
      list << s unless sess[:level].include? :server
    end
    
    return list
  end
  
  def update(cookie)
    # update the time of the session (to avoid timeout)
    @sessions[cookie][:time] = Time.now.getutc.to_i
  end
  
  def get(cookie)
    return @sessions[cookie]
  end
  
  def delete(cookie)
    return @sessions.delete(cookie) != nil
  end
  
  # default timeout is 15 minutes
  # this timeout is calculated from the last time the cookie was checked
  def timeout(delta = 900)
    trace :debug, "Session Manager timing out entries..." if @sessions.length > 0
    # save the size of the hash before deletion
    size = @sessions.length
    # search for timed out sessions
    @sessions.each_pair do |key, value|
      now = Time.now.getutc.to_i
      if now - value[:time] >= delta
        
        # don't log timeout for the server
        unless value[:level].include? :server
          Audit.log :actor => value[:user][:name], :action => 'logout', :user_name => value[:user][:name], :desc => "User '#{value[:user][:name]}' has been logged out for timeout"
        end

        trace :info, "User '#{value[:user][:name]}' has been logged out for timeout" unless value[:level] == :server
        # delete the entry
        @sessions.delete key
      end
    end
    trace :info, "Session Manager timed out #{size - @sessions.length} sessions" if size - @sessions.length > 0
  end

  def length
    return @sessions.length
  end

  def get_accessible(user)
    
    # the list of accessible Items
    accessible = []
    
    # search all the groups which the user belongs to
    ::Group.any_in({_id: user.group_ids}).each do |group|
      # add all the accessible operations
      accessible += group.item_ids
      # for each operation search the Items belonging to it
      group.item_ids.each do |operation|
        # it is enough to search in the _path to check the membership
        ::Item.any_in({path: [operation]}).each do |item|
          accessible << item[:_id]
        end
      end
    end

    return accessible
  end

  def add_accessible(factory, agent)
    # add to all the active session the new agent
    # if the factory of the agent is in the accessible list, we are sure that even
    # the agent will be in the list
    @sessions.each_pair do |cookie, sess|
      sess[:accessible] << agent[:_id] if sess[:accessible].include? factory[:_id]
    end
  end

end #SessionManager

end #DB::
end #RCS::