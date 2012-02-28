#
# Controller for the Versions (console and db)
#

module RCS
module DB

class VersionController < RESTController

  def index
    db_version = File.open(Dir.pwd + '/config/version.txt', 'r') {|f| f.read}
    console_version = "-1"

    last_console = Dir[Dir.pwd + '/console/rcs-console*.air'].sort.last
    unless last_console.nil?
      ver = Regexp.new('.*?(rcs-console-)([0-9]{10})', Regexp::IGNORECASE).match(last_console)
      console_version = ver[2].nil? ? "-1" : ver[2]
    end

    versions = {:console => console_version, :db => db_version}

    return ok(versions)
  end

  def show
    console_file = Dir.pwd + "/console/rcs-console-#{@params['_id']}.air"

    return not_found() unless File.exist?(console_file)
    
    return ok(File.binread(console_file), {:content_type => 'binary/octet-stream'})
  end
  
end

end #DB::
end #RCS::