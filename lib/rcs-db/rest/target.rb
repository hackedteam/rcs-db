
module RCS
module DB

class TargetController < RESTController
  
  def index
    require_auth_level :admin, :tech, :view
    
    filter = JSON.parse(@params['filter']) if @params.has_key? 'filter'
    filter ||= {}
    
    filter.merge!({_kind: "target"})
    filter.merge!({_id: {"$in" => @session[:accessible]}}) unless (admin? and @params['all'] == "true")

    mongoid_query do
      db = DB.instance.new_mongo_connection
      j = db.collection('items').find(filter, :fields => ["name", "desc", "status", "_kind", "path", "stat.last_sync", "stat.size", "stat.grid_size", "stat.last_child"])
      ok(j)
    end
  end
  
  def show
    require_auth_level :admin, :tech, :view

    return not_found() unless @session[:accessible].include? BSON::ObjectId.from_string(@params['_id'])

    mongoid_query do
      db = DB.instance.new_mongo_connection
      j = db.collection('items').find({_id: BSON::ObjectId.from_string(@params['_id'])}, :fields => ["name", "desc", "status", "_kind", "path", "stat"])

      target = j.first
      return not_found if target.nil?
      ok(target)
    end
  end
  
  def create
    require_auth_level :admin
    require_auth_level :admin_targets

    # to create a target, we need to owning operation
    return bad_request('INVALID_OPERATION') unless @params.has_key? 'operation'
    
    mongoid_query do
      
      operation = ::Item.operations.find(@params['operation'])
      return bad_request('INVALID_OPERATION') if operation.nil?
      
      item = Item.create(name: @params['name']) do |doc|
        doc[:_kind] = :target
        doc[:path] = [operation._id]
        doc.stat = ::Stat.new
        doc.stat.evidence = {}
        doc.stat.size = 0
        doc.stat.grid_size = 0

        doc[:status] = :open
        doc[:desc] = @params['desc']
      end

      # make item accessible to the current user (immediately)
      SessionManager.instance.add_accessible(@session, item._id)

      # make item accessible to the users
      SessionManager.instance.rebuild_all_accessible

      Audit.log :actor => @session[:user][:name],
                :action => "target.create",
                :operation_name => operation['name'],
                :target_name => item['name'],
                :desc => "Created target '#{item['name']}'"
      
      ok(item)
    end
  end

  def update
    require_auth_level :admin
    require_auth_level :admin_targets

    updatable_fields = ['name', 'desc', 'status']

    mongoid_query do
      item = Item.targets.any_in(_id: @session[:accessible]).find(@params['_id'])
      
      @params.delete_if {|k, v| not updatable_fields.include? k }
      
      @params.each_pair do |key, value|
        if item[key.to_s] != value and not key['_ids']
          Audit.log :actor => @session[:user][:name],
                    :action => "target.update",
                    :target_name => item['name'],
                    :desc => "Updated '#{key}' to '#{value}'"
        end
      end
      
      item.update_attributes(@params)
      
      return ok(item)
    end
  end

  def destroy
    require_auth_level :admin
    require_auth_level :admin_targets

    mongoid_query do
      item = Item.targets.any_in(_id: @session[:accessible]).find(@params['_id'])
      name = item.name

      Audit.log :actor => @session[:user][:name],
                :action => "target.delete",
                :target_name => name,
                :desc => "Deleted target '#{name}'"

      item.destroy

      return ok
    end
  end

  def move
    require_auth_level :admin
    require_auth_level :admin_targets

    mongoid_query do
      operation = ::Item.operations.find(@params['operation'])
      return bad_request('INVALID_OPERATION') if operation.nil?

      target = Item.targets.any_in(_id: @session[:accessible]).find(@params['_id'])
      target.path = [operation._id]
      target.save

      # update the path in alerts and connectors
      ::Alert.all.each {|a| a.update_path(target._id, target.path + [target._id])}
      ::Connector.all.each {|a| a.update_path(target._id, target.path + [target._id])}

      # move every agent and factory belonging to this target
      Item.any_in({_kind: ['agent', 'factory']}).in({path: [ target._id ]}).each do |agent|
        agent.path = target.path + [target._id]
        agent.save

        # update the path in alerts and connectors
        ::Alert.all.each {|a| a.update_path(agent._id, agent.path + [agent._id])}
        ::Connector.all.each {|a| a.update_path(agent._id, agent.path + [agent._id])}
      end

      # also move the linked entity
      Entity.any_in({type: :target}).in({path: [ target._id ]}).each do |entity|
        entity.path = target.path + [target._id]
        entity.save
      end

      Audit.log :actor => @session[:user][:name],
                :action => "#{target._kind}.move",
                (target._kind + '_name').to_sym => @params['name'],
                :desc => "Moved #{target._kind} '#{target['name']}' to #{operation['name']}"

      return ok
    end
  end

end

end
end
