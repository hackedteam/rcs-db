#
# Controller for Items
#


module RCS
module DB

class ItemController < RESTController

  def index
    require_auth_level :admin, :tech, :view

    mongoid_query do
      items = ::Item.any_in(_id: @session[:accessible]).only(:name, :desc, :status, :_kind, :_path, :stat)

      return RESTController.reply.ok(items)
    end
  end

  def show
    require_auth_level :admin, :tech, :view

    return RESTController.reply.not_found unless @session[:accessible].include? BSON::ObjectId.from_string(@params['_id'])

    mongoid_query do
      item = ::Item.find(@params['_id'])
      return RESTController.reply.ok(item)
    end
  end

  def create

  end

  def update

  end

  def destroy

  end

end

end #DB::
end #RCS::