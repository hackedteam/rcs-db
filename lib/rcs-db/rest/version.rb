#
# Controller for the Versions (console and db)
#

module RCS
module DB

class VersionController < RESTController

  def index
    db_version = File.read(Config.instance.file('VERSION'))
    console_version = "-1"

    last_console = Dir[$execution_directory + '/console/rcs-console*.air'].sort.last
    unless last_console.nil?
      ver = Regexp.new('.*?(rcs-console-)([0-9]{10})', Regexp::IGNORECASE).match(last_console)
      console_version = ver[2].nil? ? "-1" : ver[2]
    end

    versions = {:console => console_version, :db => db_version}

    return ok(versions)
  end

  def show
    console_file = $execution_directory + "/console/rcs-console-#{@params['_id']}.air"

    return not_found() unless File.exist?(console_file)

    trace :info, "Console update (#{@params['_id']}) sent to client"

    return stream_file(console_file)
  end
  
end

end #DB::
end #RCS::