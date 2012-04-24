module RCS
module DB

class OperationController < RESTController
  
  def index
    require_auth_level :admin, :tech, :view
      
    filter = JSON.parse(@params['filter']) if @params.has_key? 'filter'
    filter ||= {}

    filter.merge!({ _kind: 'operation'})
    filter.merge!({_id: {"$in" => @session[:accessible]}}) unless (admin? and @params['all'] == "true")

    mongoid_query do
      db = Mongoid.database
      j = db.collection('items').find(filter, :fields => ["name", "desc", "status", "_kind", "path", "group_ids", "stat.last_sync", "stat.size", "stat.grid_size", "stat.last_child"])
      ok(j)
    end
  end
  
  def show
    require_auth_level :admin, :tech, :view
    
    return not_found() unless @session[:accessible].include? BSON::ObjectId.from_string(@params['_id'])

    mongoid_query do
      db = Mongoid.database
      j = db.collection('items').find({_id: BSON::ObjectId.from_string(@params['_id'])}, :fields => ["name", "desc", "status", "_kind", "path", "stat", "group_ids"])

      operation = j.first
      return not_found if operation.nil?
      ok(operation)
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

      if @params.has_key? 'group_ids'
        @params['group_ids'].each do |gid|
          group = ::Group.find(gid)
          item.groups << group
        end
      end

      # make item accessible to this user
      SessionManager.instance.add_single_accessible(@session, item._id)

      Audit.log :actor => @session[:user][:name],
                :action => "operation.create",
                :operation_name => item['name'],
                :desc => "Created operation '#{item['name']}'"

      ok(item)
    end
  end
  
  def update
    require_auth_level :admin
    
    updatable_fields = ['name', 'desc', 'status', 'contact']

    mongoid_query do
      item = Item.operations.any_in(_id: @session[:accessible]).find(@params['_id'])

      # recreate the groups associations
      if @params.has_key? 'group_ids'
        item.groups = nil
        @params['group_ids'].each do |gid|
          group = ::Group.find(gid)
          item.groups << group
        end
      end

      @params.delete_if {|k, v| not updatable_fields.include? k }

      @params.each_pair do |key, value|
        if item[key.to_s] != value and not key['_ids']
          Audit.log :actor => @session[:user][:name],
                    :action => "operation.update",
                    :operation_name => item['name'],
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
      item = Item.operations.any_in(_id: @session[:accessible]).find(@params['_id'])
      name = item.name

      Audit.log :actor => @session[:user][:name],
                :action => "operation.delete",
                :operation_name => name,
                :desc => "Deleted operation '#{name}'"

      item.destroy

      return ok
    end
  end

end

end
end

