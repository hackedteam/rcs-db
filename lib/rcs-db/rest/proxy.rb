#
# Controller for the Proxy objects
#

module RCS
module DB

class ProxyController < RESTController

  def index
    require_auth_level :server, :tech

    list = DB.proxies
    
    return STATUS_OK, *json_reply(list)
  end

  def version
    require_auth_level :server

    DB.proxy_set_version(params['proxy_id'], params['version'])

    return STATUS_OK
  end

  def config
    require_auth_level :server
    
    #TODO: implement config retrieval
  end

  def log
    require_auth_level :server

    time = Time.parse(params['time'])
    DB.proxy_add_log(params['proxy_id'], time, params['type'], params['desc'])

    return STATUS_OK
  end

end

end #DB::
end #RCS::
