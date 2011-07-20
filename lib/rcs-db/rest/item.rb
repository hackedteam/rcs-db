#
# Controller for Items
#


module RCS
module DB

class ItemController < RESTController
  
  def index
    require_auth_level :admin, :tech, :view
    
    filter = JSON.parse(@params['filter']) if @params.has_key? 'filter'
    filter ||= {}
    
    mongoid_query do
      items = ::Item.where(filter)
        .any_in(_id: @session[:accessible])
        .only(:name, :desc, :status, :_kind, :path, :stat)
      
      RESTController.reply.ok(items)
    end
  end
  
  def show
    require_auth_level :admin, :tech, :view
    
    mongoid_query do
      item = ::Item.find(@params['_id']).any_in(_id: @session[:accessible])
      RESTController.reply.ok(item)
    end
  end

end

end #DB::
end #RCS::
