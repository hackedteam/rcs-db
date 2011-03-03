#
# Controller for the User objects
#

module RCS
module DB

class UserController < RESTController

  def index
    trace :debug, "INDEX #{params}"
  end

  def show
    trace :debug, "SHOW #{params}"
  end

  def create
    trace :debug, "CREATE #{params}"
  end

  def update
    trace :debug, "UPDATE #{params}"
  end

  def destroy
    trace :debug, "DESTROY #{params}"
  end

end

end #DB::
end #RCS::