#
# Controller for Build
#

require_relative '../build'

module RCS
module DB

class BuildController < RESTController

  def create
    require_auth_level :tech

    platform = @params['platform']

    # instantiate the correct builder
    begin
      build = Build.factory(platform.to_sym)
    rescue Exception => e
      return RESTController.reply.not_found(e.message)
    end

    begin
      build.create @params

      trace :debug, "Output: #{build.outputs}"

      build.clean
      
      return RESTController.reply.ok()
    rescue Exception => e
      return RESTController.reply.server_error(e.message)
    end

  end


end

end #DB::
end #RCS::