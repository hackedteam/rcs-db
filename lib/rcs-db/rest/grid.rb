require_relative '../grid'

module RCS
module DB

class GridController < RESTController
  
  def show
    require_auth_level :admin, :tech, :viewer
    
    grid_id = @params['name']
    task = GridFS.instance.get grid_id
    
    return STATUS_NOT_FOUND if task.nil?
    return STATUS_OK, *json_reply(task)
  end
  
  def destroy
    require_auth_level :admin, :tech, :viewer
    
    grid_id = @params['name']
    task = GridFS.instance.get grid_id
    
    return STATUS_OK
  end
  
end
  
end # ::DB
end # ::RCS