module RCS
module DB

class OperationController < RESTController

  def index
    require_auth_level :admin, :tech, :view

    filter = JSON.parse(@params['filter']) if @params.has_key? 'filter'
    filter ||= {}
    
    mongoid_query do
      items = ::Item.operations.where(filter)
      items = items.any_in(_id: @session[:accessible])
      items = items.only(:name, :desc, :status, :_kind, :path, :stat)
      
      RESTController.reply.ok(items)
    end
  end
  
  def show
    require_auth_level :admin, :tech, :view
    
    mongoid_query do
      item = Item.operations.any_in(_id: @session[:accessible]).find(@params['_id'])
      RESTController.reply.ok(item)
    end
  end
  
  def create
    require_auth_level :admin
    
    mongoid_query do
      item = Item.create(name: @params['name']) do |doc|
        doc[:_kind] = :operation
        doc[:path] = []
        doc[:stat] = Stat.new
        
        doc[:desc] = @params['desc']
        doc[:status] = :open
        doc[:contact] = @params['contact']
      end
      
      # make item accessible to this user
      @session[:accessible] << item._id
      
      Audit.log :actor => @session[:user][:name], :action => "operation.create", :operation => item['name'], :desc => "Created operation '#{item['name']}'"

      RESTController.reply.ok(item)
    end
  end

  def update
    require_auth_level :admin
    
    updatable_fields = ['name', 'desc', 'status', 'contact']
    
    mongoid_query do
      item = Item.operations.any_in(_id: @session[:accessible]).find(@params['_id'])
      @params.delete('_id')
      @params.delete_if {|k, v| not updatable_fields.include? k }
      
      @params.each_pair do |key, value|
        if item[key.to_s] != value and not key['_ids']
          Audit.log :actor => @session[:user][:name], :action => "operation.update", :operation => item['name'], :desc => "Updated '#{key}' to '#{value}' for #{item._kind} '#{item['name']}'"
        end
      end

      item.update_attributes(@params)
      
      return RESTController.reply.ok(item)
    end
  end
  
  def destroy
    require_auth_level :admin

    mongoid_query do
      item = Item.operations.any_in(_id: @session[:accessible]).find(@params['_id'])
      item.destroy
      
      Audit.log :actor => @session[:user][:name], :action => "operation.delete", :operation => @params['name'], :desc => "Deleted #{item._kind} '#{item['name']}'"
      return RESTController.reply.ok
    end
  end

end

end
end

