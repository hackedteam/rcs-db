#
# Controller for Items
#


module RCS
module DB

class SearchController < RESTController
  
  def index
    require_auth_level :admin, :tech, :view, :sys
    
    filter = JSON.parse(@params['filter']) if @params.has_key? 'filter'
    filter ||= {}
    
    mongoid_query do
      items = ::Item.where(filter)
        .any_in(_id: @session[:accessible])
        .only(:name, :desc, :status, :_kind, :path, :stat, :type, :platform, :instance, :version, :demo)
      
      ok(items)
    end
  end
  
  def show
    require_auth_level :admin, :tech, :view
    
    return not_found() unless @session[:accessible].include? BSON::ObjectId.from_string(@params['_id'])
    
    mongoid_query do
      item = ::Item.where({:_id => @params['_id']}).only(:name, :desc, :status, :_kind, :path, :stat)
      ok(item.first)
    end
  end
  
end

end #DB::
end #RCS::
