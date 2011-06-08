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

  def create(user, level, address)

    # create a new random cookie
    #cookie = SecureRandom.random_bytes(8).unpack('H*').first
    cookie = UUIDTools::UUID.random_create.to_s

    # store the sessions
    @sessions[cookie] = {:user => user,
                         :level => level,
                         :cookie => cookie,
                         :address => address,
                         :time => Time.now.getutc.to_i}

    return @sessions[cookie]
  end

  def check(cookie)
    return false if @sessions[cookie].nil?

    # update the time of the session (to avoid timeout)
    @sessions[cookie][:time] = Time.now.getutc.to_i

    return true
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
      list << sess unless sess[:level].include? :server
    end
    
    return list
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
      if Time.now.getutc.to_i - value[:time] >= delta then
        
        # don't log timeout for the server
        unless value[:level].include? :server
          Audit.log :actor => value[:user][:name], :action => 'logout', :user => value[:user][:name], :desc => "User '#{value[:user][:name]}' has been logged out for timeout"
        end

        trace :info, "Session Timeout for [#{value[:cookie]}]"
        # delete the entry
        @sessions.delete key
      end
    end
    trace :info, "Session Manager timed out #{size - @sessions.length} sessions" if size - @sessions.length > 0
  end

  def length
    return @sessions.length
  end
end #SessionManager

end #DB::
end #RCS::