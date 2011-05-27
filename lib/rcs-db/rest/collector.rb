#
# Controller for the Collector objects
#

module RCS
module DB

class CollectorController < RESTController

  def index
    require_auth_level :server, :tech

    mongoid_query do
      result = ::Collector.all

      return STATUS_OK, *json_reply(result)
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

    time = Time.parse(params['time'])

    #TODO: insert in capped collections

    return STATUS_OK
  end

end

end #DB::
end #RCS::
