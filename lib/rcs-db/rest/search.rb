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
    
    filter = JSON.parse(@params['filter']) if @params.has_key? 'filter'
    filter ||= {}
    
    filter.merge!({_id: {"$in" => @session[:accessible]}})

    mongoid_query do
      db = Mongoid.database
      j = db.collection('items').find(filter, :fields => ["name", "desc", "status", "_kind", "path", "type", "platform", "instance", "version", "demo"])
      ok(j)
    end
  end
  
  def show
    require_auth_level :admin, :tech, :view
    
    return not_found() unless @session[:accessible].include? BSON::ObjectId.from_string(@params['_id'])

    mongoid_query do
      db = Mongoid.database
      j = db.collection('items').find({_id: BSON::ObjectId.from_string(@params['_id'])}, :fields => ["name", "desc", "status", "_kind", "path", "stat", "type", "platform", "instance", "version", "demo"])
      ok(j.first)
    end
  end
  
end

end #DB::
end #RCS::
