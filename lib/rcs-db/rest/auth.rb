#
# Controller for the Auth objects
#

module RCS
module DB

class AuthController < RESTController

  def login
    trace :debug, "LOGIN #{params}"
  end

  def logout
    trace :debug, "LOGOUT #{params}"
  end
end

end #DB::
end #RCS::