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
      return not_found(e.message)
    end

    begin
      build.create @params

      trace :info, "Output: #{build.outputs} #{File.size(build.path(build.outputs.first)).to_s_bytes}"

      #return stream_file(build.path(build.outputs.first), proc { build.clean })
      return stream_file('cores/offline.zip', proc { build.clean })

    rescue Exception => e
      return server_error(e.message)
    end

  end

end

end #DB::
end #RCS::