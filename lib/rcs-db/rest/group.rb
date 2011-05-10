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
      group = Group.find(params[:group])
      return STATUS_NOT_FOUND if group.nil?
      return STATUS_OK, *json_reply(group)
    end
  end
  
  def create
    require_auth_level :admin

    result = Group.create(name: @params['name'])
    return STATUS_CONFLICT, *json_reply(result.errors[:name]) unless result.persisted?
    Audit.log :actor => @session[:user], :action => 'group.create', :group => @params['name'], :desc => "Created group '#{@params['name']}'"
    return STATUS_OK, *json_reply(result)
  end
  
  def update
    require_auth_level :admin

    mongoid_query do
      group = Group.find(params[:group])
      return STATUS_NOT_FOUND if group.nil?
      params.delete(:group)
      result = group.update_attributes(params)
      return STATUS_OK, *json_reply(group)
    end
  end
  
  def destroy
    require_auth_level :admin

    mongoid_query do
      group = Group.find(params[:group])
      return STATUS_NOT_FOUND if group.nil?
      group.destroy
      return STATUS_OK
    end
  end

  def add_user
    require_auth_level :admin

    mongoid_query do
      group = Group.find(params['group'])
      return STATUS_NOT_FOUND if group.nil?
      user = User.find(params['user'])
      trace :debug, user.inspect
      return STATUS_NOT_FOUND if user.nil?
      group.users << user
      return STATUS_OK
    end
  end
  
  def del_user
    require_auth_level :admin
    
    mongoid_query do
      group = Group.find(params['group'])
      return STATUS_NOT_FOUND if group.nil?
      group.users.where(_id: params['user']).destroy_all
      return STATUS_OK
    end
  end
  
end

end #DB::
end #RCS::