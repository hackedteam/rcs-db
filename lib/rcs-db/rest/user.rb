#
# Controller for the User objects
#

require 'digest/sha1'

module RCS
module DB

class UserController < RESTController

  def index
    require_auth_level :admin
    require_auth_level :admin_users

    users = User.all
    return ok(users)
  end

  def show
    require_auth_level :admin, :tech, :view

    # we need to leave access to themselves for everyone
    return not_found('User not found') if !admin? && @params['_id'] != @session.user[:_id].to_s

    mongoid_query do
      user = User.find(@params['_id'])
      return ok(user)
    end
  end
  
  def create
    require_auth_level :admin
    require_auth_level :admin_users

    return conflict('LICENSE_LIMIT_REACHED') unless LicenseManager.instance.check :users

    user = User.create(name: @params['name']) do |doc|

      doc[:pass] = ''

      password = @params['pass']
      doc[:pass] = doc.create_password(password) if password != '' and not password.nil?

      doc[:desc] = @params['desc']
      doc[:contact] = @params['contact']
      doc[:privs] = @params['privs']
      doc[:enabled] = @params['enabled']
      doc[:locale] = @params['locale']
      doc[:timezone] = @params['timezone']
      doc[:dashboard_ids] = []
      doc[:recent_ids] = []
    end
    
    return conflict(user.errors[:name]) unless user.persisted?

    if @params.has_key? 'group_ids'
      @params['group_ids'].each do |gid|
        group = ::Group.find(gid)
        group.users << user
      end
    end

    username = @params['name']
    Audit.log :actor => @session.user[:name], :action => 'user.create', :user_name => username, :desc => "Created the user '#{username}'"

    return ok(user)
  end
  
  def update
    require_auth_level :admin, :sys, :tech, :view
    
    mongoid_query do
      user = User.find(@params['_id'])
      @params.delete('_id')
      
      # if non-admin you can modify only yourself
      unless @session[:level].include? :admin
        return not_found("User not found") if user._id != @session.user[:_id]
      end
      
      # if enabling a user, check the license
      if user[:enabled] == false and @params.include?('enabled') and @params['enabled'] == true
        return conflict('LICENSE_LIMIT_REACHED') unless LicenseManager.instance.check :users
      end

      # if pass is modified, treat it separately
      if @params.has_key? 'pass'
        @params['pass'] = user.create_password(@params['pass'])
        Audit.log :actor => @session.user[:name], :action => 'user.update', :user_name => user['name'], :desc => "Changed password for user '#{user['name']}'"
      else
        @params.each_pair do |key, value|
          if key == 'dashboard_ids'
            value.collect! {|x| Moped::BSON::ObjectId(x)}
          end
          if user[key.to_s] != value and not key['_ids']
            Audit.log :actor => @session.user[:name], :action => 'user.update', :user_name => user['name'], :desc => "Updated '#{key}' to '#{value}' for user '#{user['name']}'"
          end
        end
      end
      
      result = user.update_attributes(@params)
      
      return ok(user)
    end
  end

  def add_recent
    require_auth_level :admin, :sys, :tech, :view

    mongoid_query do
      case @params['section']
        when 'operations'
          item = ::Item.find(@params['id'])
          case item._kind
            when 'operation'
              Audit.log :actor => @session.user[:name], :action => 'operation.view', :operation_name => item['name'], :desc => "Has accessed the operation: #{item.name}"
            when 'target'
              Audit.log :actor => @session.user[:name], :action => 'target,view', :target_name => item['name'], :desc => "Has accessed the target: #{item.name}"
            when 'factory'
              Audit.log :actor => @session.user[:name], :action => 'factory.view', :agent_name => item['name'], :desc => "Has accessed the factory: #{item.name}"
            when 'agent'
              Audit.log :actor => @session.user[:name], :action => 'agent.view', :agent_name => item['name'], :desc => "Has accessed the agent: #{item.name}"
          end
          recent = {section: 'operations', type: item._kind, id: item.id}
        when 'intelligence'
          case @params['type']
            when 'entity'
              entity = ::Entity.find(@params['id'])
              Audit.log :actor => @session.user[:name], :action => 'entity.view', :entity_name => entity['name'], :desc => "Has accessed the entity: #{entity.name}"
              recent = {section: 'intelligence', type: 'entity', id: entity.id}
            when 'operation'
              item = ::Item.find(@params['id'])
              Audit.log :actor => @session.user[:name], :action => 'operation.view', :operation_name => item['name'], :desc => "Has accessed the operation: #{item.name}"
              recent = {section: 'intelligence', type: 'operation', id: item.id}
          end
      end

      @session.user.add_recent(recent)

      return ok(@session.user)
    end
  end

  def destroy
    require_auth_level :admin
    require_auth_level :admin_users

    mongoid_query do
      user = User.find(@params['_id'])
      
      Audit.log :actor => @session.user[:name], :action => 'user.destroy', :user_name => @params['name'], :desc => "Deleted the user '#{user['name']}'"
      
      user.destroy
      
      return ok
    end
  end

  def message
    require_auth_level :admin
    require_auth_level :admin_users

    mongoid_query do
      if @params['_id'].nil?
        PushManager.instance.notify('message', {from: @session.user[:name], text: @params['text']})
      else
        user = User.find(@params['_id'])
        PushManager.instance.notify('message', {from: @session.user[:name], rcpt: user[:_id], text: @params['text']})
      end

      return ok
    end
  end

end

end #DB::
end #RCS::