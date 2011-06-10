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

      return STATUS_OK, *json_reply(result)
    end
  end

  def create
    require_auth_level :admin

    result = Collector.create(name: @params['name'], type: 'remote', port: 4444, poll: false, configured: false)

    Audit.log :actor => @session[:user][:name], :action => 'collector.create', :desc => "Created the collector '#{@params['name']}'"

    return STATUS_OK, *json_reply(result)
  end

  def update
    require_auth_level :admin

    mongoid_query do
      coll = Collector.find(params['collector'])
      params.delete('collector')
      return STATUS_NOT_FOUND if coll.nil?

      params.each_pair do |key, value|
        if coll[key.to_s] != value and not key['_ids']
          Audit.log :actor => @session[:user][:name], :action => 'collector.update', :desc => "Updated '#{key}' to '#{value}' for collector '#{coll['name']}'"
        end
      end

      coll.update_attributes(params)

      return STATUS_OK, *json_reply(coll)
    end
  end

  def destroy
    require_auth_level :admin

    mongoid_query do
      collector = Collector.find(params['collector'])
      collector.destroy

      return STATUS_OK
    end    
  end

  def version
    require_auth_level :server

    mongoid_query do
      collector = Collector.find(params['_id'])
      params.delete('_id')
      return STATUS_NOT_FOUND if collector.nil?

      collector.update_attributes(params)

      return STATUS_OK
    end
  end

  def config
    require_auth_level :server
    
    #TODO: implement config retrieval
    #TODO: mark as configured...

    return STATUS_NOT_FOUND
  end

  def log
    require_auth_level :server

    time = Time.parse(params['time']).getutc.to_i

    collector = Collector.find(params['_id'])
    db = Mongoid.database
    coll = db['log.' + collector[:_id].to_s]
    coll.save({time: time, type: params['type'].downcase, desc: params['desc']})

    return STATUS_OK
  end

end

end #DB::
end #RCS::
