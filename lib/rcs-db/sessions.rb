#
#  Session Manager, manages all the cookies
#

# from RCS::Common
require 'rcs-common/trace'

# system
require 'singleton'
require 'uuidtools'

module RCS
module DB

class SessionManager
  include Singleton
  include RCS::Tracer

  def initialize
    @sessions = {}
  end

  def create(uid, user, level)

    # create a new random cookie
    #cookie = SecureRandom.random_bytes(8).unpack('H*').first
    cookie = UUIDTools::UUID.random_create.to_s

    # store the sessions
    @sessions[cookie] = {:uid => uid,
                         :user => user,
                         :level => level,
                         :cookie => cookie,
                         :time => Time.now}

    return cookie
  end

  def check(cookie)
    return false if @sessions[cookie].nil?

    # update the time of the session (to avoid timeout)
    @sessions[cookie][:time] = Time.now

    return true
  end

  def get(cookie)
    return @sessions[cookie]
  end

  def delete(cookie)
    @sessions.delete(cookie)
  end

  # default timeout is 15 mins
  # this timeout is calculated from the last time the cookie was checked
  def timeout(delta = 900)
    trace :debug, "Session Manager timing out entries..." if @sessions.length > 0
    # save the size of the hash before deletion
    size = @sessions.length
    # search for timeouted sessions
    @sessions.each_pair do |key, value|
      if Time.now - value[:time] >= delta then
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