#
# Controller for the User objects
#

require 'digest/sha1'

module RCS
module DB

class UserController < RESTController

  def index
    require_auth_level :admin

    users = User.all
    return RESTController.reply.ok(users)
  end

  def show
    require_auth_level :admin
    
    mongoid_query do
      user = User.find(@params['_id'])
      return RESTController.reply.not_found if user.nil?
      return RESTController.reply.ok(user)
    end
  end
  
  def create
    require_auth_level :admin
    
    result = User.create(name: @params['name']) do |doc|

      doc[:pass] = ''

      password = @params['pass']
      doc[:pass] = Digest::SHA1.hexdigest('.:RCS:.' + password) if password != '' and not password.nil?

      doc[:desc] = @params['desc']
      doc[:contact] = @params['contact']
      doc[:privs] = @params['privs']
      doc[:enabled] = @params['enabled']
      doc[:locale] = @params['locale']
      doc[:timezone] = @params['timezone']
    end
    
    return RESTController.reply.conflict(result.errors[:name]) unless result.persisted?

    username = @params['name']
    Audit.log :actor => @session[:user][:name], :action => 'user.create', :user => username, :desc => "Created the user '#{username}'"

    return RESTController.reply.ok(result)
  end
  
  def update
    require_auth_level :admin, :sys, :tech, :view
    
    mongoid_query do
      user = User.find(@params['_id'])
      return RESTController.reply.not_found if user.nil?
      @params.delete('_id')
      
      # if non-admin you can modify only yourself
      unless @session[:level].include? :admin
        return RESTController.reply.not_found if user._id != @session[:user][:_id]
      end
      
      # if enabling a user, check the license
      if user[:enabled] == false and @params.include?('enabled') and @params['enabled'] == true
        return RESTController.reply.conflict('LICENSE_LIMIT_REACHED') unless LicenseManager.instance.check :users
      end

      # if pass is modified, treat it separately
      if @params.has_key? 'pass'
        @params['pass'] = Digest::SHA1.hexdigest('.:RCS:.' + @params['pass'])
        Audit.log :actor => @session[:user][:name], :action => 'user.update', :user => user['name'], :desc => "Changed password for user '#{user['name']}'"
      else
        @params.each_pair do |key, value|
          if user[key.to_s] != value and not key['_ids']
            Audit.log :actor => @session[:user][:name], :action => 'user.update', :user => user['name'], :desc => "Updated '#{key}' to '#{value}' for user '#{user['name']}'"
          end
        end
      end
      
      result = user.update_attributes(@params)
      
      return RESTController.reply.ok(user)
    end
  end
  
  def destroy
    require_auth_level :admin
    
    mongoid_query do
      user = User.find(@params['_id'])
      return RESTController.reply.not_found if user.nil?
      
      Audit.log :actor => @session[:user][:name], :action => 'user.destroy', :user => @params['name'], :desc => "Deleted the user '#{user['name']}'"
      
      user.destroy
      
      return RESTController.reply.ok
    end
  end
  
end

end #DB::
end #RCS::