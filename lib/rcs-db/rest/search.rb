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
      
      RESTController.reply.ok(items)
    end
  end
  
  def show
    require_auth_level :admin, :tech, :view

    RESTController.reply.not_found() unless @session[:accessible].include? BSON::ObjectId.from_string(@params['_id'])

    mongoid_query do
      item = ::Item.where({:_id => @params['_id']}).only(:name, :desc, :status, :_kind, :path, :stat)
      RESTController.reply.ok(item.first)
    end
  end
  
end

end #DB::
end #RCS::
