#
# Controller for the Collector objects
#

module RCS
module DB

class CollectorController < RESTController

  def index
    require_auth_level :server, :tech, :admin

    mongoid_query do
      result = ::Collector.all

      return RESTController.ok(result)
    end
  end

  def create
    require_auth_level :admin

    result = Collector.create(name: @params['name'], type: 'remote', port: 4444, poll: false, configured: false)

    Audit.log :actor => @session[:user][:name], :action => 'collector.create', :desc => "Created the collector '#{@params['name']}'"

    return RESTController.ok(result)
  end

  def update
    require_auth_level :admin

    mongoid_query do
      coll = Collector.find(params['collector'])
      params.delete('collector')
      return RESTController.not_found if coll.nil?

      params.each_pair do |key, value|
        if coll[key.to_s] != value and not key['_ids']
          Audit.log :actor => @session[:user][:name], :action => 'collector.update', :desc => "Updated '#{key}' to '#{value}' for collector '#{coll['name']}'"
        end
      end

      coll.update_attributes(params)

      return RESTController.ok(coll)
    end
  end

  def destroy
    require_auth_level :admin

    mongoid_query do
      collector = Collector.find(params['collector'])
      collector.destroy

      return RESTController.ok
    end    
  end

  def version
    require_auth_level :server

    mongoid_query do
      collector = Collector.find(params['_id'])
      params.delete('_id')
      return RESTController.not_found if collector.nil?

      collector.update_attributes(params)

      return RESTController.ok
    end
  end

  def config
    require_auth_level :server
    
    #TODO: implement config retrieval
    #TODO: mark as configured...

    return RESTController.not_found
  end

  def log
    require_auth_level :server

    time = Time.parse(params['time']).getutc.to_i

    collector = Collector.find(params['_id'])

    entry = CappedLog.dynamic_new collector[:_id]
    entry.time = time
    entry.type = params['type'].downcase
    entry.desc = params['desc']
    entry.save

    return RESTController.ok
  end

end

end #DB::
end #RCS::
