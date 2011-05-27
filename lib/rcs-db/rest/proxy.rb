#
# Controller for the Proxy objects
#

module RCS
module DB

class ProxyController < RESTController

  def index
    require_auth_level :server, :tech

    mongoid_query do
      result = ::Proxy.all

      return STATUS_OK, *json_reply(result)
    end
  end

  def version
    require_auth_level :server

    mongoid_query do
      proxy = Proxy.find(params['_id'])
      params.delete('_id')
      return STATUS_NOT_FOUND if proxy.nil?

      proxy.update_attributes(params)

      return STATUS_OK
    end
  end

  def config
    require_auth_level :server
    
    #TODO: implement config retrieval
  end

  def log
    require_auth_level :server

    time = Time.parse(params['time'])

    #TODO: insert in capped collections

    return STATUS_OK
  end

end

end #DB::
end #RCS::
