require_relative '../grid'

module RCS
module DB

class GridController < RESTController
  
  def show
    require_auth_level :admin, :tech, :viewer
    
    grid_id = @params['name']
    task = GridFS.instance.get grid_id
    
    return RESTController.not_found if task.nil?
    return RESTController.ok(task)
  end
  
  def destroy
    require_auth_level :admin, :tech, :viewer
    
    grid_id = @params['name']
    task = GridFS.instance.get grid_id
    
    return RESTController.ok
  end
  
end
  
end # ::DB
end # ::RCS