#
# Controller for Entity
#


module RCS
module DB

class EntityController < RESTController

  def index
    require_auth_level :view
    require_auth_level :view_profiles

    #TODO: filter on accessible
    #where({_id: {"$in" => @session[:accessible]}})

    mongoid_query do
      entities = ::Entity.all
      return ok(entities)
    end
  end

  def show
    require_auth_level :view
    require_auth_level :view_profiles

    return not_found() unless @session[:accessible].include? BSON::ObjectId.from_string(@params['_id'])

    mongoid_query do
      ent = ::Entity.find(@params['_id'])
      return ok(ent)
    end
  end

  def create
    require_auth_level :view
    require_auth_level :view_profiles

    mongoid_query do

      operation = ::Item.operations.find(@params['operation'])
      return bad_request('INVALID_OPERATION') if operation.nil?

      if @params['target'].nil?
        target = nil
      else
        target = ::Item.targets.find(@params['target'])
        return bad_request('INVALID_TARGET') if target.nil?
      end

      e = ::Entity.create!() do |doc|
        doc[:path] = [operation._id]
        doc[:path] << target._id unless target.nil?
        doc[:name] = @params['name']
        doc[:type] = @params['type'].to_sym
        doc[:desc] = @params['desc']
      end

      Audit.log :actor => @session[:user][:name], :action => 'entity.create', :desc => "Created a new entity named #{e.name}"

      return ok(e)
    end    
  end

  def update
    require_auth_level :view
    require_auth_level :view_profiles

    mongoid_query do
      e = ::Entity.find(@params['_id'])
      #e = ::Entity.any_in(_id: @session[:accessible]).find(@params['_id'])
      @params.delete('_id')

      @params.each_pair do |key, value|
        if key == 'path'
          value.collect! {|x| BSON::ObjectId(x)} 
        end
        if alert[key.to_s] != value and not key['_ids']
          Audit.log :actor => @session[:user][:name], :action => 'entity.update', :desc => "Updated '#{key}' to '#{value}' for entity #{e.name}"
        end
      end

      e.update_attributes(@params)

      return ok(e)
    end
  end

  def destroy
    require_auth_level :view
    require_auth_level :view_profiles

    mongoid_query do

      e = Entity.find(@params['_id'])
      Audit.log :actor => @session[:user][:name], :action => 'entity.destroy', :desc => "Deleted the entity #{e.name}"
      e.destroy

      # TODO: push notification
      #PushManager.instance.notify('alert', {rcpt: @session[:user][:_id]})

      return ok
    end
  end


end

end #DB::
end #RCS::