require 'tmpdir'

module RCS
module DB

class UploadController < RESTController

  def create
    require_auth_level :tech

    # ensure the temp dir is present
    Dir::mkdir(Config.instance.temp) if not File.directory?(Config.instance.temp)

    t = Time.now
    name = @session[:user][:_id].to_s + "-" + "%10.9f" % t.to_f
    path = Config.instance.temp(name)

    File.open(path, "wb+") do |f|
      # pay attention to multipart uploaded files.
      # this works if the client send the part named 'content' inside the query.
      f.write @request[:content]['content']
    end

    Audit.log :actor => @session[:user][:name], :action => 'upload.create', :desc => "Uploaded #{@request[:content]['content'].size.to_s_bytes} bytes"

    return ok(name, {:content_type => 'text/plain'})
  end

end

end # ::DB
end # ::RCS
