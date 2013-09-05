#
# Controller for Entity
#

require_relative '../link_manager'

module RCS
module DB

class EntityController < RESTController

  def index
    require_auth_level :view
    require_auth_level :view_profiles

    mongoid_query do
      fields = ["type", "level", "name", "desc", "path", "photos", 'position', 'position_attr', 'links']
      filter = {'user_ids' => @session.user[:_id], 'level' => {'$ne' => :ghost}}
      fields = fields.inject({}) { |h, f| h[f] = 1; h }

      entities = ::Entity.collection.find(filter).select(fields).entries.map! do |ent|
        link_size = ent['links'] ? ent['links'].keep_if {|x| x['level'] != :ghost}.size : 0
        ent.delete('links')
        ent['num_links'] = link_size
        ent['position'] = {longitude: ent['position'][0], latitude: ent['position'][1]} if ent['position'].is_a? Array
        ent
      end

      ok(entities)
    end
  end

  def flow
    require_auth_level :view

    mongoid_query do
      # Check the presence of the required params
      %w[ids from to].each do |param_name|
        return bad_request('INVALID_OPERATION') if @params[param_name].blank?
      end

      return ok Entity.flow(@params)
    end
  end

  def positions
    require_auth_level :view

    mongoid_query do
      ids = [@params['ids']].flatten
      from = @params['from']
      to = @params['to']

      ok Entity.positions_flow(ids, from, to)
    end
  end

  def show
    require_auth_level :view
    require_auth_level :view_profiles

    mongoid_query do
      ent = ::Entity.where(_id: @params['_id']).in(user_ids: [@session.user[:_id]]).only(['type', 'level', 'name', 'desc', 'path', 'photos', 'position', 'position_attr', 'handles', 'links'])
      entity = ent.first
      return not_found if entity.nil?
      return not_found if entity.level == :ghost

      # convert position to hash {:latitude, :longitude}
      entity = entity.as_document
      entity['position'] = {longitude: entity['position'][0], latitude: entity['position'][1]} if entity['position'].is_a? Array

      # don't send ghost links
      entity['links'].keep_if {|l| l['level'] != :ghost} if entity['links']

      ok(entity)
    end
  end

  def create
    require_auth_level :view
    require_auth_level :view_profiles

    return conflict('LICENSE_LIMIT_REACHED') unless LicenseManager.instance.check :intelligence

    mongoid_query do

      operation = ::Item.operations.find(@params['operation'])
      return bad_request('INVALID_OPERATION') if operation.nil?

      e = ::Entity.create! do |doc|
        doc[:path] = [operation._id]
        doc.users = operation.users
        doc[:name] = @params['name']
        doc[:type] = @params['type'].to_sym
        doc[:desc] = @params['desc']
        doc[:level] = :manual
        if @params['position'] and @params['position'].size > 0
          doc.position = [@params['position']['longitude'].to_f, @params['position']['latitude'].to_f]
          doc.position_attr[:accuracy] = @params['position_attr']['accuracy'].to_i
        end
      end

      Audit.log :actor => @session.user[:name], :action => 'entity.create', :entity_name => e.name, :desc => "Created a new entity named #{e.name}"

      # convert position to hash {:latitude, :longitude}
      entity = e.as_document
      entity['position'] = {longitude: entity['position'][0], latitude: entity['position'][1]}  if entity['position'].is_a? Array
      entity.delete('analyzed')

      return ok(entity)
    end    
  end

  def update
    require_auth_level :view
    require_auth_level :view_profiles

    mongoid_query do
      entity = ::Entity.any_in(user_ids: [@session.user[:_id]]).find(@params['_id'])
      @params.delete('_id')

      if @params['position'] and @params['position'].size > 0
        entity.position = [@params['position']['longitude'].to_f, @params['position']['latitude'].to_f]
        entity.position_attr[:accuracy] = @params['position_attr']['accuracy'].to_i
        entity.save
        @params.delete('position')
        @params.delete('position_attr')
      end

      @params.each_pair do |key, value|
        if key == 'path'
          value.collect! {|x| Moped::BSON::ObjectId(x)}
        end
        if entity[key.to_s] != value and not key['_ids']
          Audit.log :actor => @session.user[:name], :action => 'entity.update', :entity_name => entity.name, :desc => "Updated '#{key}' to '#{value}' for entity #{entity.name}"
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

      Audit.log :actor => @session.user[:name], :action => 'entity.destroy', :entity_name => e.name, :desc => "Deleted the entity #{e.name}"
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

      Audit.log :actor => @session.user[:name], :action => 'entity.add_photo', :entity_name => e.name, :desc => "Added a new photo to #{e.name}"

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

      Audit.log :actor => @session.user[:name], :action => 'entity.add_photo', :entity_name => e.name, :desc => "Added a new photo to #{e.name}"

      return ok(id)
    end
  end

  def del_photo
    require_auth_level :view
    require_auth_level :view_profiles

    mongoid_query do

      e = Entity.any_in(user_ids: [@session.user[:_id]]).find(@params['_id'])
      return not_found() unless e.del_photo(@params['photo_id'])

      Audit.log :actor => @session.user[:name], :action => 'entity.del_photo', :entity_name => e.name, :desc => "Deleted a photo from #{e.name}"

      return ok
    end
  end

  def add_handle
    require_auth_level :view
    require_auth_level :view_profiles

    mongoid_query do

      e = Entity.any_in(user_ids: [@session.user[:_id]]).find(@params['_id'])
      e.handles.create!(level: :manual, type: @params['type'].downcase, name: @params['name'], handle: @params['handle'].downcase)

      Audit.log :actor => @session.user[:name], :action => 'entity.add_handle', :entity_name => e.name, :desc => "Added a the handle '#{@params['handle'].downcase}' to #{e.name}"

      return ok
    end
  end

  def del_handle
    require_auth_level :view
    require_auth_level :view_profiles

    mongoid_query do

      e = Entity.any_in(user_ids: [@session.user[:_id]]).find(@params['_id'])
      e.handles.find(@params['handle_id']).destroy

      Audit.log :actor => @session.user[:name], :action => 'entity.del_handle', :entity_name => e.name, :desc => "Deleted an handle from #{e.name}"

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

  def most_visited_urls
    require_auth_level :view
    require_auth_level :view_profiles

    return conflict('LICENSE_LIMIT_REACHED') unless LicenseManager.instance.check :correlation

    mongoid_query do
      entity = Entity.any_in(user_ids: [@session.user[:_id]]).find(@params['_id'])
      return conflict('NO_AGGREGATES_FOR_ENTITY') unless entity.type.eql? :target

      # extract the most contacted peers for this entity
      contacted = Aggregate.most_visited_urls(entity.path.last.to_s, @params)

      return ok(contacted)
    end
  end

  def most_visited_places
    require_auth_level :view
    require_auth_level :view_profiles

    return conflict('LICENSE_LIMIT_REACHED') unless LicenseManager.instance.check :correlation

    mongoid_query do
      entity = Entity.any_in(user_ids: [@session.user[:_id]]).find(@params['_id'])
      return conflict('NO_AGGREGATES_FOR_ENTITY') unless entity.type.eql? :target

      # extract the most contacted peers for this entity
      contacted = Aggregate.most_visited_places(entity.path.last.to_s, @params)

      return ok(contacted)
    end
  end

  def add_link
    require_auth_level :view
    require_auth_level :view_profiles

    return conflict('LICENSE_LIMIT_REACHED') unless LicenseManager.instance.check :intelligence

    mongoid_query do

      e = Entity.any_in(user_ids: [@session.user[:_id]]).find(@params['_id'])
      e2 = Entity.any_in(user_ids: [@session.user[:_id]]).find(@params['entity'])

      return not_found() if e.nil? or e2.nil?

      link = RCS::DB::LinkManager.instance.add_link(from: e, to: e2, level: :manual, type: @params['type'].to_sym, versus: @params['versus'].to_sym, rel: @params['rel'])

      Audit.log :actor => @session.user[:name], :action => 'entity.add_link', :entity_name => e.name, :desc => "Added a new link between #{e.name} and #{e2.name}"
      Audit.log :actor => @session.user[:name], :action => 'entity.add_link', :entity_name => e2.name, :desc => "Added a new link between #{e.name} and #{e2.name}"

      return ok(link)
    end
  end

  def edit_link
    require_auth_level :view
    require_auth_level :view_profiles

    return conflict('LICENSE_LIMIT_REACHED') unless LicenseManager.instance.check :intelligence

    mongoid_query do

      e = Entity.any_in(user_ids: [@session.user[:_id]]).find(@params['_id'])
      e2 = Entity.any_in(user_ids: [@session.user[:_id]]).find(@params['entity'])

      return not_found() if e.nil? or e2.nil?

      link = RCS::DB::LinkManager.instance.edit_link(from: e, to: e2, level: :manual, type: @params['type'].to_sym, versus: @params['versus'].to_sym, rel: @params['rel'])

      Audit.log :actor => @session.user[:name], :action => 'entity.add_link', :entity_name => e.name, :desc => "Added a new link between #{e.name} and #{e2.name}"
      Audit.log :actor => @session.user[:name], :action => 'entity.add_link', :entity_name => e2.name, :desc => "Added a new link between #{e.name} and #{e2.name}"

      return ok(link)
    end
  end

  def del_link
    require_auth_level :view
    require_auth_level :view_profiles

    return conflict('LICENSE_LIMIT_REACHED') unless LicenseManager.instance.check :intelligence

    mongoid_query do

      e = Entity.any_in(user_ids: [@session.user[:_id]]).find(@params['_id'])
      e2 = Entity.any_in(user_ids: [@session.user[:_id]]).find(@params['entity'])

      return not_found() if e.nil? or e2.nil?

      RCS::DB::LinkManager.instance.del_link(from: e, to: e2)

      Audit.log :actor => @session.user[:name], :action => 'entity.del_link', :entity_name => e.name, :desc => "Deleted a link between #{e.name} and #{e2.name}"
      Audit.log :actor => @session.user[:name], :action => 'entity.del_link', :entity_name => e2.name, :desc => "Deleted a link between #{e.name} and #{e2.name}"

      return ok
    end
  end

  def merge
    require_auth_level :view
    require_auth_level :view_profiles

    return conflict('LICENSE_LIMIT_REACHED') unless LicenseManager.instance.check :intelligence

    mongoid_query do

      e = Entity.any_in(user_ids: [@session.user[:_id]]).find(@params['_id'])
      e2 = Entity.any_in(user_ids: [@session.user[:_id]]).find(@params['entity'])

      return not_found() if e.nil? or e2.nil?

      e.merge(e2)

      Audit.log :actor => @session.user[:name], :action => 'entity.merge', :entity_name => e.name, :desc => "Merged entity '#{e.name}' and '#{e2.name}'"
      Audit.log :actor => @session.user[:name], :action => 'entity.merge', :entity_name => e2.name, :desc => "Merged entity '#{e.name}' and '#{e2.name}'"

      return ok(e)
    end
  end

end

end #DB::
end #RCS::