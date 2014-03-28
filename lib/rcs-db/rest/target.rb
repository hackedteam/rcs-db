#
# Controller for the Target objects
#

module RCS
module DB

class TargetController < RESTController
  
  def index
    require_auth_level :admin, :tech, :view

    mongoid_query do
      fields = ["name", "desc", "status", "_kind", "path", "stat.last_sync", "stat.size", "stat.grid_size", "stat.last_child"]
      targets = ::Item.targets.in(user_ids: [@session.user[:_id]]).only(fields)
      ok(targets)
    end
  end
  
  def show
    require_auth_level :admin, :tech, :view

    mongoid_query do
      tar = ::Item.operations.where(_id: @params['_id']).in(user_ids: [@session.user[:_id]]).only("name", "desc", "status", "_kind", "path", "stat")
      target = tar.first
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
        doc.users = operation.users
        doc.stat = ::Stat.new
        doc.stat.evidence = {}
        doc.stat.size = 0
        doc.stat.grid_size = 0

        doc[:status] = :open
        doc[:desc] = @params['desc']
      end

      Audit.log :actor => @session.user[:name],
                :action => "target.create",
                :_item => item,
                :desc => "Created target '#{item['name']}'"
      
      ok(item)
    end
  end

  def update
    require_auth_level :admin
    require_auth_level :admin_targets

    updatable_fields = ['name', 'desc', 'status']

    mongoid_query do
      item = Item.targets.any_in(user_ids: [@session.user[:_id]]).find(@params['_id'])
      
      @params.delete_if {|k, v| not updatable_fields.include? k }
      
      @params.each_pair do |key, value|
        if item[key.to_s] != value and not key['_ids']
          Audit.log :actor => @session.user[:name],
                    :action => "target.update",
                    :_item => item,
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
      item = Item.targets.any_in(user_ids: [@session.user[:_id]]).find(@params['_id'])
      name = item.name

      Audit.log :actor => @session.user[:name],
                :action => "target.delete",
                :_item => item,
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

      src_operation = target.get_parent

      target = Item.targets.any_in(user_ids: [@session.user[:_id]]).find(@params['_id'])

      target.move_target(operation)

      Audit.log :actor => @session.user[:name],
                :action => "#{target._kind}.move",
                :_item => target,
                :desc => "Moved #{target._kind} '#{target.name}' from '#{src_operation.name}' to '#{operation.name}'"

      return ok
    end
  end
end

end
end
