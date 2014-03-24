#
# Controller for the Factory objects
#

module RCS
module DB

class FactoryController < RESTController
  
  def index
    require_auth_level :tech, :view

    mongoid_query do
      fields = ["name", "desc", "status", "_kind", "path", "type", "ident", "good"]
      factories = ::Item.factories.in(deleted: [false, nil]).in(user_ids: [@session.user[:_id]]).only(fields)
      ok(factories)
    end
  end
  
  def show
    require_auth_level :tech, :view

    mongoid_query do
      fa = ::Item.where(_id: @params['_id'], deleted: false).in(user_ids: [@session.user[:_id]]).only("name", "desc", "status", "_kind", "path", "ident", "counter", "logkey", "confkey", "configs", "good")
      factory = fa.first
      return not_found if factory.nil?
      ok(factory)
    end
  end

  def update
    require_auth_level :tech
    
    updatable_fields = ['name', 'desc', 'status']

    mongoid_query do
      item = Item.factories.any_in(user_ids: [@session.user[:_id]]).find(@params['_id'])

      @params.delete_if {|k, v| not updatable_fields.include? k }
      
      @params.each_pair do |key, value|
        if item[key.to_s] != value and not key['_ids']
          Audit.log :actor  => @session.user[:name],
                    :action => "#{item._kind}.update",
                    :_item  => item,
                    :desc   => "Updated '#{key}' to '#{value}' for #{item._kind} '#{item['name']}'"
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
      item = Item.factories.any_in(user_ids: [@session.user[:_id]]).find(@params['_id'])
      item.deleted = true
      item.status = 'closed'
      item.save

      Audit.log :actor  => @session.user[:name],
                :action => "#{item._kind}.delete",
                :_item  => item,
                :desc   => "Deleted #{item._kind} '#{item['name']}'"
      
      return ok
    end
  end

end

end
end