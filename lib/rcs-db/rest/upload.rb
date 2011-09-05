require 'tmpdir'

module RCS
module DB

class UploadController < RESTController

  def create
    require_auth_level :tech

    t = Time.now
    name = @session[:user][:_id].to_s + "-" + "%10.9f" % t.to_f
    path = File.join Dir.tmpdir, name

    File.open(path, "wb+") do |f|
      f.write @request[:content]
    end

    Audit.log :actor => @session[:user][:name], :action => 'upload.create', :desc => "Uploaded #{@request[:content].size.to_s_bytes} bytes"

    return RESTController.reply.ok(name)
  end

end

end # ::DB
end # ::RCS
