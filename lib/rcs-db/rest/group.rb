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
    return ok(groups)
  end

  def show
    require_auth_level :admin

    mongoid_query do
      group = Group.find(@params['_id'])
      return ok(group)
    end
  end
  
  def create
    require_auth_level :admin
    
    result = Group.create(name: @params['name'])
    return conflict(result.errors[:name]) unless result.persisted?

    Audit.log :actor => @session[:user][:name], :action => 'group.create', :group_name => @params['name'], :desc => "Created the group '#{@params['name']}'"

    return ok(result)
  end
  
  def update
    require_auth_level :admin

    mongoid_query do
      group = Group.find(@params['_id'])
      @params.delete('_id')
      
      @params.each_pair do |key, value|
        if group[key.to_s] != value and not key['_ids']
          Audit.log :actor => @session[:user][:name], :action => 'group.update', :group_name => group['name'], :desc => "Updated '#{key}' to '#{value}' for group '#{group['name']}'"
        end
      end
      
      group.update_attributes(@params)
      
      return ok(group)
    end
  end
  
  def destroy
    require_auth_level :admin

    mongoid_query do
      group = Group.find(@params['_id'])
      
      Audit.log :actor => @session[:user][:name], :action => 'group.destroy', :group_name => @params['name'], :desc => "Deleted the group '#{group[:name]}'"
      
      group.destroy
      return ok
    end
  end

  def add_user
    require_auth_level :admin

    mongoid_query do
      group = Group.find(@params['_id'])
      user = User.find(@params['user']['_id'])
      
      group.users << user

      # recalculate the accessible list for logged in users
      SessionManager.instance.rebuild_all_accessible

      Audit.log :actor => @session[:user][:name], :action => 'group.add_user', :group_name => @params['name'], :desc => "Added user '#{user.name}' to group '#{group.name}'"
      
      return ok
    end
  end
  
  def del_user
    require_auth_level :admin
    
    mongoid_query do
      group = Group.find(@params['_id'])
      user = User.find(@params['user']['_id'])

      group.users.delete(user)

      # recalculate the accessible list for logged in users
      SessionManager.instance.rebuild_all_accessible

      Audit.log :actor => @session[:user][:name], :action => 'group.remove_user', :group_name => @params['name'], :desc => "Removed user '#{user.name}' from group '#{group.name}'"
      
      return ok
    end
  end

  def add_operation
    require_auth_level :admin

    mongoid_query do
      group = Group.find(@params['_id'])
      operation = Item.find(@params['operation']['_id'])

      group.items << operation

      # recalculate the accessible list for logged in users
      SessionManager.instance.rebuild_all_accessible

      Audit.log :actor => @session[:user][:name], :action => 'group.add_operation', :group_name => @params['name'], :desc => "Added operation '#{operation.name}' to group '#{group.name}'"

      return ok
    end
  end

  def del_operation
    require_auth_level :admin

    mongoid_query do
      group = Group.find(@params['_id'])
      operation = Item.find(@params['operation']['_id'])

      group.items.delete(operation)

      # recalculate the accessible list for logged in users
      SessionManager.instance.rebuild_all_accessible

      Audit.log :actor => @session[:user][:name], :action => 'group.remove_operation', :group_name => @params['name'], :desc => "Removed operation '#{operation.name}' from group '#{group.name}'"

      return ok
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
          Audit.log :actor => @session[:user][:name], :action => 'group.alert', :group_name => @params['name'], :desc => "Monitor alert group set to '#{g[:name]}'"
        end
        g.save
      end
      
      if @params['group'].nil?
        Audit.log :actor => @session[:user][:name], :action => 'group.alert', :group_name => @params['name'], :desc => "Monitor alert group was removed"
      end
      
      return ok
    end
  end

end

end #DB::
end #RCS::