module RCS
module DB

class FactoryController < RESTController
  
  def index
    require_auth_level :tech, :view
    
    filter = JSON.parse(@params['filter']) if @params.has_key? 'filter'
    filter ||= {}

    filter.merge!({_id: {"$in" => @session[:accessible]}, _kind: 'factory'})

    mongoid_query do
      db = Mongoid.database
      j = db.collection('items').find(filter, :fields => ["name", "desc", "status", "_kind", "path", "type", "ident"])
      ok(j)
    end
  end
  
  def show
    require_auth_level :tech, :view

    return not_found() unless @session[:accessible].include? BSON::ObjectId.from_string(@params['_id'])

    mongoid_query do
      db = Mongoid.database
      j = db.collection('items').find({_id: BSON::ObjectId.from_string(@params['_id'])}, :fields => ["name", "desc", "status", "_kind", "path", "ident", "counter", "logkey", "confkey", "configs"])
      ok(j.first)
    end
  end

  def update
    require_auth_level :tech
    
    updatable_fields = ['name', 'desc', 'status']

    mongoid_query do
      item = Item.factories.any_in(_id: @session[:accessible]).find(@params['_id'])

      @params.delete_if {|k, v| not updatable_fields.include? k }
      
      @params.each_pair do |key, value|
        if item[key.to_s] != value and not key['_ids']
          Audit.log :actor => @session[:user][:name],
                    :action => "#{item._kind}.update",
                    (item._kind + '_name').to_sym => item['name'],
                    :desc => "Updated '#{key}' to '#{value}' for #{item._kind} '#{item['name']}'"
        end
      end
      
      item.update_attributes(@params)
      
      item = Item.factories
        .only(:name, :desc, :status, :_kind, :path, :ident, :counter, :configs)
        .find(item._id)
      
      return ok(item)
    end
  end
  
  def destroy
    require_auth_level :tech
    
    mongoid_query do
      item = Item.factories.any_in(_id: @session[:accessible]).find(@params['_id'])
      item.destroy
      
      Audit.log :actor => @session[:user][:name],
                :action => "#{item._kind}.delete",
                (item._kind + '_name').to_sym => @params['name'],
                :desc => "Deleted #{item._kind} '#{item['name']}'"
      
      return ok
    end
  end

end

end
end