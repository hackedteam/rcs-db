#
# Controller for the Backdoor objects
#

module RCS
module DB

class BackdoorController < RESTController

  def class_keys

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

end

end #DB::
end #RCS::
