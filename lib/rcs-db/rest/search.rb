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
    
    filter.merge!({_id: {"$in" => @session[:accessible]}, deleted: {"$in" => [false, nil]}})

    mongoid_query do
      db = Mongoid.database
      j = db.collection('items').find(filter, :fields => ["name", "desc", "status", "_kind", "path", "type", "platform", "instance", "version", "demo", "ident"])
      ok(j)
    end
  end
  
  def show
    require_auth_level :admin, :tech, :view
    
    return not_found() unless @session[:accessible].include? BSON::ObjectId.from_string(@params['_id'])

    mongoid_query do
      db = Mongoid.database
      j = db.collection('items').find({_id: BSON::ObjectId.from_string(@params['_id'])}, :fields => ["name", "desc", "status", "_kind", "path", "stat", "type", "ident", "platform", "instance", "version", "demo", "deleted"])

      agent = j.first

      # the console MUST not see deleted items
      return not_found if agent.nil?
      return not_found if agent.has_key?('deleted') and agent['deleted']

      ok(agent)
    end
  end
  
end

end #DB::
end #RCS::
