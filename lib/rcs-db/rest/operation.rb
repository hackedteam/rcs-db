module RCS
module DB

class OperationController < RESTController
  
  def index
    require_auth_level :admin, :tech, :view
      
    filter = JSON.parse(@params['filter']) if @params.has_key? 'filter'
    filter ||= {}
    
    mongoid_query do
      items = ::Item.operations.where(filter)
      items = items.any_in(_id: @session[:accessible]) unless (admin? and @params['all'] == "true")
      items = items.only(:name, :desc, :status, :_kind, :path, :stat)
      
      RESTController.reply.ok(items)
    end
  end
  
  def show
    require_auth_level :admin, :tech, :view
    
    mongoid_query do
      item = Item.operations
        .any_in(_id: @session[:accessible])
        .only(:name, :desc, :status, :_kind, :path, :stat)
        .find(@params['_id'])
      
      RESTController.reply.ok(item)
    end
  end
  
  def create
    require_auth_level :admin
    
    mongoid_query do
      item = Item.create(name: @params['name']) do |doc|
        doc[:_kind] = :operation
        doc[:path] = []
        doc.stat = ::Stat.new
        doc.stat.evidence = {}
        doc.stat.size = 0
        doc.stat.grid_size = 0

        doc[:desc] = @params['desc']
        doc[:status] = :open
        doc[:contact] = @params['contact']
      end

      @params['group_ids'].each do |gid|
        group = ::Group.find(gid)
        item.groups << group
      end

      # make item accessible to this user
      @session[:accessible] << item._id
      
      Audit.log :actor => @session[:user][:name],
                :action => "operation.create",
                :operation => item['name'],
                :desc => "Created operation '#{item['name']}'"

      RESTController.reply.ok(item)
    end
  end
  
  def update
    require_auth_level :admin
    
    updatable_fields = ['name', 'desc', 'status', 'contact']
    
    mongoid_query do
      item = Item.operations.any_in(_id: @session[:accessible]).find(@params['_id'])

      # recreate the groups associations
      item.groups = nil
      @params['group_ids'].each do |gid|
        group = ::Group.find(gid)
        item.groups << group
      end

      @params.delete_if {|k, v| not updatable_fields.include? k }

      @params.each_pair do |key, value|
        if item[key.to_s] != value and not key['_ids']
          Audit.log :actor => @session[:user][:name],
                    :action => "operation.update",
                    :operation => item['name'],
                    :desc => "Updated '#{key}' to '#{value}'"
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
      name = item.name
      _kind = item._kind
      
      item.destroy
      
      Audit.log :actor => @session[:user][:name],
                :action => "operation.delete",
                :operation => name,
                :desc => "Deleted operation '#{name}'"
      
      return RESTController.reply.ok
    end
  end

end

end
end

