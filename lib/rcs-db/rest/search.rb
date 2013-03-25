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
      items = ::Item.in(deleted: [false, nil]).in(user_ids: [@session[:user][:_id]]).only(fields)
      ok(items)
    end
  end
  
  def show
    require_auth_level :admin, :tech, :view

    mongoid_query do
      it = ::Item.where(_id: @params['_id'], deleted: false).in(user_ids: [@session[:user][:_id]]).only("name", "desc", "status", "_kind", "path", "stat", "type", "ident", "platform", "instance", "version", "demo", "scout", "deleted")
      item = it.first
      return not_found if item.nil?
      ok(item)
    end
  end
  
end

end #DB::
end #RCS::
