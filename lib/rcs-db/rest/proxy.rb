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

      return RESTController.ok(result)
    end
  end

  def version
    require_auth_level :server

    mongoid_query do
      proxy = Proxy.find(params['_id'])
      params.delete('_id')
      return RESTController.not_found if proxy.nil?

      proxy.update_attributes(params)

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

    time = Time.parse(params['time'])

    #TODO: insert in capped collections

    return RESTController.ok
  end

end

end #DB::
end #RCS::
