#
# Controller for Items
#

require 'mongo'
require 'mongoid'

module RCS
module DB

class SearchController < RESTController
  
  def index
    require_auth_level :admin, :tech, :view, :sys
    
    mongoid_query do
      fields = ["name", "desc", "status", "_kind", "path", "type", "platform", "instance", "version", "demo", "level", "ident"]
      items = ::Item.in(deleted: [false, nil]).in(user_ids: [@session.user[:_id]]).only(fields)
      items = items.to_a

      entities = ::Entity.in(level: [:automatic, :manual]).in(user_ids: [@session.user[:_id]]).only(["name", "desc", "path", "type"]).to_a
      entities.map! {|x| x.as_document.merge({_kind: 'entity'})}

      ok(items + entities)
    end
  end
  
  def show
    require_auth_level :admin, :tech, :view

    mongoid_query do
      item = ::Item.where(_id: @params['_id'], deleted: false).in(user_ids: [@session.user[:_id]]).only("name", "desc", "status", "_kind", "path", "stat", "type", "ident", "platform", "instance", "version", "demo", "level", "deleted").first
      return ok(item) unless item.nil?

      entity = ::Entity.where(_id: @params['_id']).in(user_ids: [@session.user[:_id]]).only("name", "desc", "path", "type").first
      return ok(entity) unless entity.nil?

      return not_found
    end
  end
  
end

end #DB::
end #RCS::
