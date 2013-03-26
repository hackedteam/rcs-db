#
# Controller for Entity
#


module RCS
module DB

class EntityController < RESTController

  def index
    require_auth_level :view
    require_auth_level :view_profiles

    mongoid_query do
      fields = ["type", "level", "name", "path", "photos"]
      entities = ::Entity.in(user_ids: [@session.user[:_id]]).only(fields)
      ok(entities)
    end
  end

  def show
    require_auth_level :view
    require_auth_level :view_profiles

    mongoid_query do
      ent = ::Entity.where(_id: @params['_id']).in(user_ids: [@session.user[:_id]])
      entity = ent.first
      return not_found if entity.nil?

      # convert position to hash {:latitude, :longitude}
      entity = entity.as_document
      entity['position'] = {longitude: entity['position'][0], latitude: entity['position'][1]}

      ok(entity)
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

      e = ::Entity.create! do |doc|
        doc[:path] = [operation._id]
        doc[:path] << target._id unless target.nil?
        doc[:name] = @params['name']
        doc[:type] = @params['type'].to_sym
        doc[:desc] = @params['desc']
        doc[:level] = :manual
        if @params['position']
          doc.position = [@params['position']['longitude'], @params['position']['latitude']]
          doc.position_attr[:accuracy] = @params['position']['accuracy']
        end
      end

      Audit.log :actor => @session.user[:name], :action => 'entity.create', :desc => "Created a new entity named #{e.name}"

      return ok(e)
    end    
  end

  def update
    require_auth_level :view
    require_auth_level :view_profiles

    mongoid_query do
      entity = ::Entity.any_in(user_ids: [@session.user[:_id]]).find(@params['_id'])
      @params.delete('_id')

      @params.each_pair do |key, value|
        if key == 'path'
          value.collect! {|x| Moped::BSON::ObjectId(x)}
        end
        if entity[key.to_s] != value and not key['_ids']
          Audit.log :actor => @session.user[:name], :action => 'entity.update', :desc => "Updated '#{key}' to '#{value}' for entity #{entity.name}"
        end
      end

      entity.update_attributes(@params)

      return ok(entity)
    end
  end

  def destroy
    require_auth_level :view
    require_auth_level :view_profiles

    mongoid_query do

      e = Entity.any_in(user_ids: [@session.user[:_id]]).find(@params['_id'])

      # entity created by target cannot be deleted manually, they will disappear with their target
      return conflict('CANNOT_DELETE_TARGET_ENTITY') if e.type == :target

      Audit.log :actor => @session.user[:name], :action => 'entity.destroy', :desc => "Deleted the entity #{e.name}"
      e.destroy

      return ok
    end
  end

  def add_photo
    require_auth_level :view
    require_auth_level :view_profiles

    mongoid_query do

      e = Entity.any_in(user_ids: [@session.user[:_id]]).find(@request[:content]['_id'])
      id = e.add_photo(@request[:content]['content'])

      Audit.log :actor => @session.user[:name], :action => 'entity.add_photo', :desc => "Added a new photo to #{e.name}"

      return ok(id)
    end
  end

  def add_photo_from_grid
    require_auth_level :view
    require_auth_level :view_profiles

    mongoid_query do

      e = Entity.any_in(user_ids: [@session.user[:_id]]).find(@params['_id'])
      file = GridFS.get(Moped::BSON::ObjectId.from_string(@params['_grid']), @params['target_id'])
      id = e.add_photo(file.read)

      Audit.log :actor => @session.user[:name], :action => 'entity.add_photo', :desc => "Added a new photo to #{e.name}"

      return ok(id)
    end
  end

  def del_photo
    require_auth_level :view
    require_auth_level :view_profiles

    mongoid_query do

      e = Entity.any_in(user_ids: [@session.user[:_id]]).find(@params['_id'])
      return not_found() unless e.del_photo(@params['photo_id'])

      Audit.log :actor => @session.user[:name], :action => 'entity.del_photo', :desc => "Deleted a photo from #{e.name}"

      return ok
    end
  end

  def add_handle
    require_auth_level :view
    require_auth_level :view_profiles

    mongoid_query do

      e = Entity.any_in(user_ids: [@session.user[:_id]]).find(@params['_id'])
      e.handles.create!(level: :manual, type: @params['type'], name: @params['name'], handle: @params['handle'])

      Audit.log :actor => @session.user[:name], :action => 'entity.add_handle', :desc => "Added a new handle to #{e.name}"

      return ok
    end
  end

  def del_handle
    require_auth_level :view
    require_auth_level :view_profiles

    mongoid_query do

      e = Entity.any_in(user_ids: [@session.user[:_id]]).find(@params['_id'])
      e.handles.destroy_all(conditions: { _id: @params['handle_id'] })

      Audit.log :actor => @session.user[:name], :action => 'entity.del_handle', :desc => "Deleted an handle from #{e.name}"

      return ok
    end
  end

  def most_contacted
    require_auth_level :view
    require_auth_level :view_profiles

    return conflict('LICENSE_LIMIT_REACHED') unless LicenseManager.instance.check :correlation

    mongoid_query do
      entity = Entity.any_in(user_ids: [@session.user[:_id]]).find(@params['_id'])
      return conflict('NO_AGGREGATES_FOR_ENTITY') unless entity.type.eql? :target

      # extract the most contacted peers for this entity
      contacted = Aggregate.most_contacted(entity.path.last.to_s, @params)

      return ok(contacted)
    end
  end

  def add_place
    require_auth_level :view
    require_auth_level :view_profiles

    mongoid_query do

      e = Entity.any_in(user_ids: [@session.user[:_id]]).find(@params['_id'])
      return conflict('NOT_A_TARGET') unless e.type.eql? :target

      e.add_place(name: @params['name'], latitude: @params['latitude'], longitude: @params['longitude'], accuracy: @params['accuracy'])

      Audit.log :actor => @session.user[:name], :action => 'entity.add_palce', :desc => "Added a new place to #{e.name}"

      return ok
    end
  end

end

end #DB::
end #RCS::