require_relative '../position/resolver'

module RCS
module DB

class PositionController < RESTController

  bypass_auth [:create]

  def create
    resp = PositionResolver.get @params['map']
    return ok(resp)
  end

end
  
end # ::DB
end # ::RCS