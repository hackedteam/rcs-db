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
      fields = ["name", "desc", "status", "_kind", "path", "type", "platform", "instance", "version", "demo", "scout", "ident"]
      items = ::Item.in(deleted: [false, nil]).in(_id: @session[:accessible]).only(fields)
      ok(items)
    end
  end
  
  def show
    require_auth_level :admin, :tech, :view
    
    return not_found() unless @session[:accessible].include? Moped::BSON::ObjectId.from_string(@params['_id'])

    mongoid_query do
      it = ::Item.where(_id: @params['_id'], deleted: false).only("name", "desc", "status", "_kind", "path", "stat", "type", "ident", "platform", "instance", "version", "demo", "scout", "deleted")
      item = it.first
      return not_found if item.nil?
      ok(item)
    end
  end
  
end

end #DB::
end #RCS::
