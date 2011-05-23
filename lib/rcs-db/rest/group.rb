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
    return STATUS_OK, *json_reply(groups)
  end

  def show
    require_auth_level :admin

    mongoid_query do
      group = Group.find(params['group'])
      return STATUS_NOT_FOUND if group.nil?
      return STATUS_OK, *json_reply(group)
    end
  end
  
  def create
    require_auth_level :admin

    result = Group.create(name: @params['name'])
    return STATUS_CONFLICT, *json_reply(result.errors[:name]) unless result.persisted?

    Audit.log :actor => @session[:user][:name], :action => 'group.create', :group => @params['name'], :desc => "Created the group '#{@params['name']}'"

    return STATUS_OK, *json_reply(result)
  end
  
  def update
    require_auth_level :admin

    mongoid_query do
      group = Group.find(params['group'])
      params.delete('group')
      return STATUS_NOT_FOUND if group.nil?
      
      params.each_pair do |key, value|
        if group[key.to_s] != value and not key['_ids']
          Audit.log :actor => @session[:user][:name], :action => 'group.update', :group => group['name'], :desc => "Updated '#{key}' to '#{value}' for group '#{group['name']}'"
        end
      end
      
      result = group.update_attributes(params)
      
      return STATUS_OK, *json_reply(group)
    end
  end
  
  def destroy
    require_auth_level :admin

    mongoid_query do
      group = Group.find(params['group'])
      return STATUS_NOT_FOUND if group.nil?
      
      Audit.log :actor => @session[:user][:name], :action => 'group.destroy', :group => @params['name'], :desc => "Deleted the group '#{group[:name]}'"
      
      group.destroy
      return STATUS_OK
    end
  end

  def add_user
    require_auth_level :admin

    mongoid_query do
      group = Group.find(params['group'])
      user = User.find(params['user'])
      return STATUS_NOT_FOUND if user.nil? or group.nil?

      group.users << user
      
      Audit.log :actor => @session[:user][:name], :action => 'group.add_user', :group => @params['name'], :desc => "Added user '#{user.name}' to group '#{group.name}'"
      
      return STATUS_OK
    end
  end
  
  def del_user
    require_auth_level :admin
    
    mongoid_query do
      group = Group.find(params['group'])
      user = User.find(params['user'])
      return STATUS_NOT_FOUND if user.nil? or group.nil?

      group.remove_user(user)
      
      Audit.log :actor => @session[:user][:name], :action => 'group.remove_user', :group => @params['name'], :desc => "Removed user '#{user.name}' from group '#{group.name}'"
      
      return STATUS_OK
    end
  end

  def alert
    require_auth_level :admin

    mongoid_query do

      groups = Group.all

      # reset all groups to false and set the unique group to true
      groups.each do |g|
        g[:alert] = false
        if not params['group'].nil? and g[:_id] == BSON::ObjectId(params['group'])
          g[:alert] = true
          Audit.log :actor => @session[:user][:name], :action => 'group.alert', :group => @params['name'], :desc => "Monitor alert group set to '#{g[:name]}'"
        end
        g.save
      end

      if params['group'].nil?
        Audit.log :actor => @session[:user][:name], :action => 'group.alert', :group => @params['name'], :desc => "Monitor alert group was removed"
      end
      
      return STATUS_OK
    end
  end

end

end #DB::
end #RCS::