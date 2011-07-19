
module RCS
module DB

class TargetController < RESTController

  def index
    require_auth_level :admin, :tech, :view
    
    filter = JSON.parse(@params['filter']) if @params.has_key? 'filter'
    filter ||= {}
  
    mongoid_query do
      items = ::Item.targets.where(filter)
      items = items.any_in(_id: @session[:accessible])
      items = items.only(:name, :desc, :status, :_kind, :path, :stat)

      RESTController.reply.ok(items)
    end
  end
  
  def show
    require_auth_level :admin, :tech, :view

    mongoid_query do
      item = Item.targets.any_in(_id: @session[:accessible]).find(@params['_id'])
      RESTController.reply.ok(item)
    end
  end

  def create
    require_auth_level :admin
    
    # to create a target, we need to owning operation
    return RESTController.reply.bad_request('INVALID_OPERATION') unless @params.has_key? 'operation'
    
    mongoid_query do
      
      operation = ::Item.where({_id: @params['operation'], _kind: 'operation'}).first
      return RESTController.reply.bad_request('INVALID_OPERATION') if operation.nil?
      
      item = Item.create(name: @params['name']) do |doc|
        doc[:_kind] = :target
        doc[:path] = [operation._id]
        doc[:stat] = Stat.new
        doc[:status] = :open
        doc[:desc] = @params['desc']
      end
      
      @session[:accessible] << item._id
      
      Audit.log :actor => @session[:user][:name], :action => "target.create", :operation => item['name'], :desc => "Created target '#{item['name']}' under operation '#{operation['name']}'"
  
      RESTController.reply.ok(item)
    end
  end

  def update
    require_auth_level :admin

    mongoid_query do
      item = Item.targets.any_in(_id: @session[:accessible]).find(@params['_id'])
      @params.delete('_id')

      item.update_attributes(@params)

      @params.each_pair do |key, value|
        if item[key.to_s] != value and not key['_ids']
          Audit.log :actor => @session[:user][:name], :action => "operation.update", :operation => item['name'], :desc => "Updated '#{key}' to '#{value}' for #{item._kind} '#{item['name']}'"
        end
      end

      return RESTController.reply.ok(item)
    end
  end

  def destroy
    require_auth_level :admin

    mongoid_query do
      item = Item.targets.any_in(_id: @session[:accessible]).find(@params['_id'])
      item.destroy

      Audit.log :actor => @session[:user][:name], :action => "operation.delete", :operation => @params['name'], :desc => "Deleted #{item._kind} '#{item['name']}'"
      return RESTController.reply.ok
    end
  end

end

end
end
