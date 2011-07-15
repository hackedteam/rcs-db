require_relative '../grid'

module RCS
module DB

class FileController < RESTController
  
  def show
    require_auth_level :admin, :tech, :view
    
    file_name = @params['_id']
    file_path = File.join('temp', file_name)
    
    RESTController.reply.not_found unless File.exists? file_path
    RESTController.reply.stream_file(file_path)
  end

=begin
  def create
    require_auth_level :tech
    
    grid_id = GridFS.instance.put @request[:content]
    Audit.log :actor => @session[:user][:name], :action => 'grid.upload', :desc => "Uploaded #{@request[:content].to_s_bytes} bytes into #{grid_id}."
       
    return RESTController.reply.ok({_grid: grid_id.to_s})
  end
=end

  # TODO: verify Grid REST destroy is ever called, otherwise remove
  def destroy
    require_auth_level :none
    
    file_name = @params['_id']
    file_path = File.join('temp', file_name)
    File.unlink file_path
    
    RESTController.reply.ok
  end
  
end

end # ::DB
end # ::RCS