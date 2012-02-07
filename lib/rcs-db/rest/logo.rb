#
# Controller for the logo image
#

module RCS
module DB

class LogoController < RESTController

  def index
    return stream_file Config.instance.file('logo.png')
  end

end

end #DB::
end #RCS::
