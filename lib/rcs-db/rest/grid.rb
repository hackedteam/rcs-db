require_relative '../grid'

module RCS
module DB

class GridController < RESTController
  
  def show
    require_auth_level :admin, :tech, :viewer
    
    grid_id = @params['_id']
    
    trace :debug, "Getting grid file #{grid_id}!!!"
    file = GridFS.instance.get BSON::ObjectId.from_string grid_id
    trace :debug, "Got file '#{file.filename} of size #{file.file_length} bytes." unless file.nil?
    
    return RESTController.not_found if file.nil?
    return RESTController.stream_grid(file)
  end
  
  def destroy
    require_auth_level :admin, :tech, :viewer
    
    grid_id = @params['_id']
    GridFS.instance.delete grid_id
    
    return RESTController.ok
  end
  
end
  
end # ::DB
end # ::RCS