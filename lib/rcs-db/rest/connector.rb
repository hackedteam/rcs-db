#
# Controller for Backups
#


module RCS
module DB

class ConnectorController < RESTController

  def index
    require_auth_level :sys
    require_auth_level :sys_connectors

    mongoid_query do
      list = Connector.all.to_a
      # Adds the status attribute (real-time calculated measure)
      list.each { |c| c.attributes['status'] = c.queued_count }

      return ok(list)
    end
  end

  def create
    require_auth_level :sys
    require_auth_level :sys_connectors

    return conflict('LICENSE_LIMIT_REACHED') unless LicenseManager.instance.limits[:connectors]

    puts @params.inspect

    mongoid_query do
      f = ::Connector.new
      f.enabled = @params['enabled'] ? true : false
      f.name = @params['name']
      f.type = @params['type'] || raise('Connector type must be provided')
      f.format = @params['format'] || raise('Connector format must be provided')
      f.keep = @params['keep']
      f.enqueue_previous = @params['enqueue_previous'] || false
      f.dest = @params['dest']
      f.path = @params['path'].collect! {|x| Moped::BSON::ObjectId(x)} if @params['path'].class == Array
      f.save!

      Audit.log :actor => @session.user[:name], :action => 'connector.create', :desc => "Connector rule '#{f.name}' was created"

      return ok(f)
    end    
  end

  def update
    require_auth_level :sys
    require_auth_level :sys_connectors

    mongoid_query do
      connector = ::Connector.find(@params['_id'])
      @params.delete('_id')

      @params.each_pair do |key, value|
        if key == 'path'
          value.collect! {|x| Moped::BSON::ObjectId(x)}
        end
        if connector[key.to_s] != value
          Audit.log :actor => @session.user[:name], :action => 'connector.update', :desc => "Updated '#{key}' to '#{value}' for connector rule #{connector[:name]}"
        end
      end

      connector.update_attributes!(@params)

      return ok(connector)
    end
  end

  def destroy
    require_auth_level :sys
    require_auth_level :sys_connectors

    mongoid_query do
      connector = ::Connector.find(@params['_id'])

      if connector.in_use?
        raise("The connector is currently being used thus it cannot be deleted at the moment")
      end

      Audit.log :actor => @session.user[:name], :action => 'connector.destroy', :desc => "Deleted the connector rule [#{connector[:name]}]"
      connector.destroy

      return ok
    end
  end

end

end #DB::
end #RCS::