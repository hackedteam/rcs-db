
module RCS
module DB

class TargetController < RESTController
  
  def index
    require_auth_level :admin, :tech, :view
    
    filter = JSON.parse(@params['filter']) if @params.has_key? 'filter'
    filter ||= {}
  
    mongoid_query do
      items = ::Item.targets.where(filter)
        .any_in(_id: @session[:accessible])
        .only(:name, :desc, :status, :_kind, :path, :stat)

      ok(items)
    end
  end
  
  def show
    require_auth_level :admin, :tech, :view
    
    mongoid_query do
      item = Item.targets
        .any_in(_id: @session[:accessible])
        .only(:name, :desc, :status, :_kind, :path, :stat)
        .find(@params['_id'])
      
      ok(item)
    end
  end
  
  def create
    require_auth_level :admin
    
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
      
      @session[:accessible] << item._id
      
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

    mongoid_query do
      item = Item.targets.any_in(_id: @session[:accessible]).find(@params['_id'])
      name = item.name

      item.destroy

      Audit.log :actor => @session[:user][:name],
                :action => "target.delete",
                :target_name => name,
                :desc => "Deleted target '#{name}'"
      return ok
    end
  end

  def move
    mongoid_query do
      operation = ::Item.operations.find(@params['operation'])
      return bad_request('INVALID_OPERATION') if operation.nil?

      target = Item.targets.any_in(_id: @session[:accessible]).find(@params['_id'])
      target.path = [operation._id]
      target.save

      # move every agent and factory belonging to this target
      Item.any_in({_kind: ['agent', 'factory']}).also_in({path: [ target._id ]}).each do |agent|
        agent.path = target.path + [target._id]
        agent.save
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
