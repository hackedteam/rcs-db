#
# Controller for the User objects
#

module RCS
module DB

class UserController < RESTController

  def index
    trace :debug, "USER INDEX #{params}"
  end

  def show
    trace :debug, "USER SHOW #{params}"
  end

  def create
    trace :debug, "USER CREATE #{params}"
  end

  def update
    trace :debug, "USER UPDATE #{params}"
  end

  def destroy
    trace :debug, "USER DESTROY #{params}"
  end

end

end #DB::
end #RCS::