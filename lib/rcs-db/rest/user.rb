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
      user = User.find(params[:user])
      return STATUS_NOT_FOUND if user.nil?
      return STATUS_OK, *json_reply(user)
    end
    
  end
  
  def create
    require_auth_level :admin

    result = User.create(name: @params['name']) do |doc|
      doc[:pass] = Digest::SHA1.hexdigest('.:RCS:.' + @params['pass'])
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
    require_auth_level :admin

    mongoid_query do
      user = User.find(params[:user])
      return STATUS_NOT_FOUND if user.nil?
      params.delete(:user)
      result = user.update_attributes(params)

      Audit.log :actor => @session[:user][:name], :action => 'user.update', :user => @params['name'], :desc => "Updated the user '#{user['name']}'"

      return STATUS_OK, *json_reply(user)
    end
    
  end
  
  def destroy
    require_auth_level :admin
    
    mongoid_query do
      user = User.find(params[:user])
      return STATUS_NOT_FOUND if user.nil?

      Audit.log :actor => @session[:user][:name], :action => 'user.destroy', :user => @params['name'], :desc => "Deleted the user '#{user['name']}'"

      user.destroy

      return STATUS_OK
    end

  end

end

end #DB::
end #RCS::