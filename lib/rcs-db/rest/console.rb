#
# Controller for the Versions (console and db)
#

require 'rcs-common/mime'

module RCS
module DB

class ConsoleController < RESTController

  bypass_auth [:index, :show]

  def index
    # sugar for the users to not force them to add the trailing /
    return http_redirect('/console/') unless @request[:uri].end_with?("/")

    return not_found unless File.exist?(Dir.pwd + '/console/index.html')

    require_basic_auth

    # retrieve the latest console in the directory
    last_console = Dir[Dir.pwd + '/console/rcs-console*.air'].sort.last

    return not_found if last_console.nil?

    ver = Regexp.new('.*?(rcs-console-)([0-9]{10})', Regexp::IGNORECASE).match(last_console)
    console_version = ver[2]

    # convert 201201020301 to 12.01.02
    console_version.slice!(0..1)
    console_version.slice!(-2..-1)
    console_version.insert(2, ".")
    console_version.insert(5, ".")

    console_url = "https://"
    console_url << Config.instance.global['CN'] + ":" + Config.instance.global['LISTENING_PORT'].to_s + "/"
    console_url << "console/" + File.basename(last_console)

    trace :info, "Console installer URL is: #{console_url}"
    trace :info, "Console installer VERSION is: #{console_version}"

    index = File.read(Dir.pwd + '/console/index.html')

    index.gsub! "CONSOLE_INSTALL_URL", console_url
    index.gsub! "CONSOLE_INSTALL_VERSION", console_version

    return ok(index, {content_type: 'text/html'})
  end

  def show
    file = Dir.pwd + "/console/#{@params['_id']}"
    return stream_file(file)
  end

  private
  def http_redirect(url)
    body =  "<!DOCTYPE HTML PUBLIC \"-//IETF//DTD HTML 2.0//EN\">"
    body += "<html><head>"
    body += "<title>302 Found</title>"
    body += "</head><body>"
    body += "<h1>Found</h1>"
    body += "<p>The document has moved <a href=\"#{url}\">here</a>.</p>"
    body += "</body></html>"
    return redirect(body, {location: url})
  end

end

end #DB::
end #RCS::