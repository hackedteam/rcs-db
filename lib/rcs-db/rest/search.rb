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
    
    db = Mongoid.database
    j = db.collection('items').find(filter, :fields => ["name", "desc", "status", "_kind", "path", "type", "platform", "instance", "version", "demo"])
    
    ok(j)

=begin
    mongoid_query do
      items = ::Item.where(filter)
        .any_in(_id: @session[:accessible])
        .only(:name, :desc, :status, :_kind, :path, :stat, :type, :platform, :instance, :version, :demo)
      
      ok(items)
    end
=end
  end
  
  def show
    require_auth_level :admin, :tech, :view
    
    return not_found() unless @session[:accessible].include? BSON::ObjectId.from_string(@params['_id'])

    db = Mongoid.database
    j = db.collection('items').find({_id: BSON::ObjectId.from_string(@params['_id'])}, :fields => ["name", "desc", "status", "_kind", "path", "stat", "type", "platform", "instance", "version", "demo"])

    ok(j.first)
    
=begin
    mongoid_query do
      item = ::Item.where({:_id => @params['_id']}).only(:name, :desc, :status, :_kind, :path, :stat)
      ok(item.first)
    end
=end
  end
  
end

end #DB::
end #RCS::
