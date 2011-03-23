#
# Controller for the Collector objects
#

module RCS
module DB

class CollectorController < RESTController

  def index
    require_auth_level :server, :tech

    list = DB.collectors
    
    return STATUS_OK, *json_reply(list)
  end

  def version
    require_auth_level :server

    DB.collector_set_version(params['collector_id'], params['version'])

    return STATUS_OK
  end

  def config
    require_auth_level :server
    
    #TODO: implement config retrieval
  end

  def log
    require_auth_level :server

    time = Time.parse(params['time'])
    DB.collector_add_log(params['collector_id'], time, params['type'], params['desc'])

    return STATUS_OK
  end

end

end #DB::
end #RCS::
