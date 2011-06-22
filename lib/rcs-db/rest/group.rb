#
# Controller for the Group objects
#

require 'digest/sha1'

module RCS
module DB

class GroupController < RESTController
  
  def index
    require_auth_level :admin

    groups = Group.all
    return RESTController.ok(groups)
  end

  def show
    require_auth_level :admin

    mongoid_query do
      group = Group.find(@params['_id'])
      return RESTController.not_found if group.nil?
      return RESTController.ok(group)
    end
  end
  
  def create
    require_auth_level :admin
    
    result = Group.create(name: @params['name'])
    return RESTController.conflict(result.errors[:name]) unless result.persisted?

    Audit.log :actor => @session[:user][:name], :action => 'group.create', :group => @params['name'], :desc => "Created the group '#{@params['name']}'"

    return RESTController.ok(result)
  end
  
  def update
    require_auth_level :admin

    mongoid_query do
      group = Group.find(@params['_id'])
      @params.delete('_id')
      return RESTController.not_found if group.nil?
      
      @params.each_pair do |key, value|
        if group[key.to_s] != value and not key['_ids']
          Audit.log :actor => @session[:user][:name], :action => 'group.update', :group => group['name'], :desc => "Updated '#{key}' to '#{value}' for group '#{group['name']}'"
        end
      end
      
      result = group.update_attributes(@params)
      
      return RESTController.ok(group)
    end
  end
  
  def destroy
    require_auth_level :admin

    mongoid_query do
      group = Group.find(@params['_id'])
      return RESTController.not_found if group.nil?
      
      Audit.log :actor => @session[:user][:name], :action => 'group.destroy', :group => @params['name'], :desc => "Deleted the group '#{group[:name]}'"
      
      group.destroy
      return RESTController.ok
    end
  end

  def add_user
    require_auth_level :admin

    mongoid_query do
      group = Group.find(@params['_id'])
      user = User.find(@params['user'])
      return RESTController.not_found if user.nil? or group.nil?
      
      group.users << user
      
      Audit.log :actor => @session[:user][:name], :action => 'group.add_user', :group => @params['name'], :desc => "Added user '#{user.name}' to group '#{group.name}'"
      
      return RESTController.ok
    end
  end
  
  def del_user
    require_auth_level :admin
    
    mongoid_query do
      group = Group.find(@params['_id'])
      user = User.find(@params['user'])
      return RESTController.not_found if user.nil? or group.nil?

      group.remove_user(user)
      
      Audit.log :actor => @session[:user][:name], :action => 'group.remove_user', :group => @params['name'], :desc => "Removed user '#{user.name}' from group '#{group.name}'"
      
      return RESTController.ok
    end
  end

  def alert
    require_auth_level :admin
    
    mongoid_query do
      
      groups = Group.all
      
      # reset all groups to false and set the unique group to true
      groups.each do |g|
        g[:alert] = false
        if not @params['_id'].nil? and g[:_id] == BSON::ObjectId(@params['_id'])
          g[:alert] = true
          Audit.log :actor => @session[:user][:name], :action => 'group.alert', :group => @params['name'], :desc => "Monitor alert group set to '#{g[:name]}'"
        end
        g.save
      end
      
      if @params['group'].nil?
        Audit.log :actor => @session[:user][:name], :action => 'group.alert', :group => @params['name'], :desc => "Monitor alert group was removed"
      end
      
      return RESTController.ok
    end
  end

end

end #DB::
end #RCS::