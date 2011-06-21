require_relative '../grid'

module RCS
module DB

class GridController < RESTController
  
  def show
    require_auth_level :admin, :tech, :viewer
    
    grid_id = @params['grid']
    
    trace :debug, "getting grid file #{grid_id}!!!"
    file = GridFS.instance.get BSON::ObjectId.from_string grid_id
    trace :debug, "got file '#{file.filename} of size #{file.file_length} bytes." unless file.nil?
    
    return RESTController.not_found if file.nil?
    return RESTController.stream_grid(file)
  end

  def create
    require_auth_level :tech
    
    grid_id = GridFS.instance.put @req_content
    trace :debug, "stored #{@req_content.bytesize} bytes into Grid #{grid_id}."

    trace :debug, grid_id.inspect

    return RESTController.ok({_grid: grid_id.to_s})
  end

  # TODO: verify Grid REST destroy is ever called, otherwise remove
  def destroy
    require_auth_level :none
    
    grid_id = @params['grid']
    GridFS.instance.delete grid_id
    
    return RESTController.ok
  end
  
end
  
end # ::DB
end # ::RCS