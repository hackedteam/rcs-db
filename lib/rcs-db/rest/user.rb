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
    return STATUS_OK, *json_reply(users)
  end

  def show
    require_auth_level :admin
    
    mongoid_query do
      user = User.find(params['user'])
      return STATUS_NOT_FOUND if user.nil?
      return STATUS_OK, *json_reply(user)
    end
  end
  
  def create
    require_auth_level :admin

    result = User.create(name: @params['name']) do |doc|

      doc[:pass] = ''
      doc[:pass] = Digest::SHA1.hexdigest('.:RCS:.' + @params['pass']) if @params['pass'] != '' and not @params['pass'].nil?

      doc[:desc] = @params['desc']
      doc[:contact] = @params['contact']
      doc[:privs] = @params['privs']
      doc[:enabled] = @params['enabled']
      doc[:locale] = @params['locale']
      doc[:timezone] = @params['timezone']
    end
    
    return STATUS_CONFLICT, *json_reply(result.errors[:name]) unless result.persisted?
    
    Audit.log :actor => @session[:user][:name], :action => 'user.create', :user => @params['name'], :desc => "Created the user '#{@params['name']}'"

    return STATUS_OK, *json_reply(result)
  end
  
  def update
    require_auth_level :admin, :tech, :viewer
    
    mongoid_query do
      user = User.find(params['user'])
      return STATUS_NOT_FOUND if user.nil?
      params.delete('user')

      # if non-admin you can modify only yourself
      unless @session[:level].include? :admin
        return STATUS_NOT_FOUND if user._id != @session[:user][:_id]
      end
      
      # if enabling a user, check the license
      if user[:enabled] == false and params['enabled'] == true
        return STATUS_CONFLICT, *json_reply('LICENSE_LIMIT_REACHED') unless LicenseManager.instance.check :users
      end

      # if pass is modified, treat it separately
      if params.has_key? 'pass'
        params['pass'] = Digest::SHA1.hexdigest('.:RCS:.' + params['pass'])
        Audit.log :actor => @session[:user][:name], :action => 'user.update', :user => user['name'], :desc => "Changed password for user '#{user['name']}'"
      else
        params.each_pair do |key, value|
          if user[key.to_s] != value and not key['_ids']
            Audit.log :actor => @session[:user][:name], :action => 'user.update', :user => user['name'], :desc => "Updated '#{key}' to '#{value}' for user '#{user['name']}'"
          end
        end
      end

      result = user.update_attributes(params)
      
      return STATUS_OK, *json_reply(user)
    end
  end
  
  def destroy
    require_auth_level :admin
    
    mongoid_query do
      user = User.find(params['user'])
      return STATUS_NOT_FOUND if user.nil?
      
      Audit.log :actor => @session[:user][:name], :action => 'user.destroy', :user => @params['name'], :desc => "Deleted the user '#{user['name']}'"
      
      user.destroy
      
      return STATUS_OK
    end
  end
  
end

end #DB::
end #RCS::