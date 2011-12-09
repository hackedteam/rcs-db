require_relative '../grid'

module RCS
module DB

class GridController < RESTController
  
  def show
    require_auth_level :tech, :view
    
    grid_id = @params['_id']
    file = GridFS.get BSON::ObjectId.from_string(grid_id), @params['target_id']
    
    return not_found if file.nil?
    return stream_grid(file)
  end

  def create
    require_auth_level :tech
    
    grid_id = GridFS.put @request[:content]['content']
    Audit.log :actor => @session[:user][:name], :action => 'grid.upload', :desc => "Uploaded #{@request[:content]['content'].to_s_bytes} bytes into #{grid_id}."
       
    return ok({_grid: grid_id.to_s})
  end

  # TODO: verify Grid REST destroy is ever called, otherwise remove
  def destroy
    require_auth_level :none
    
    grid_id = @params['_id']
    GridFS.delete grid_id
    
    return ok
  end
  
end
  
end # ::DB
end # ::RCS