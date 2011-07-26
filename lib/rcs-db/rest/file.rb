require_relative '../grid'

module RCS
module DB

class FileController < RESTController
  
  def show
    require_auth_level :admin, :sys, :tech, :view
    
    file_name = @params['_id']
    file_path = File.join('temp', file_name)
    
    RESTController.reply.not_found unless File.exists? file_path
    RESTController.reply.stream_file(file_path)
  end

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