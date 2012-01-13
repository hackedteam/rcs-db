require_relative '../location'

module RCS
module DB

class LocationController < RESTController

  bypass_auth [:create]

  def create
    resp = Location.get @params['map']
    return ok(resp)
  end

end
  
end # ::DB
end # ::RCS