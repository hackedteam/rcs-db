require_relative '../tasks'

module RCS
module DB

class TaskController < RESTController
  
  def index
    require_auth_level :admin, :tech, :viewer
    
    tasks = TaskManager.instance.list @session[:user][:name]
    return RESTController.ok tasks
  end
  
  def show
    require_auth_level :admin, :tech, :viewer
    
    task = TaskManager.instance.get @session[:user][:name], params['task']

    return RESTController.not_found if task.nil?
    return RESTController.ok task
  end
  
  def create
    require_auth_level :admin, :tech, :viewer
    
    task = TaskManager.instance.create @session[:user][:name]
    
    return RESTController.not_found if task.nil?
    return RESTController.ok task
  end
  
  def destroy
    require_auth_level :admin, :tech, :viewer
    
    TaskManager.instance.delete @session[:user][:name], params['task']
    
    return RESTController.ok
  end

end

end # DB::
end # RCS::
