require_relative '../tasks'

module RCS
module DB

class TaskController < RESTController
  
  def index
    require_auth_level :admin, :tech, :viewer
    
    tasks = TaskManager.instance.list @session[:user][:name]
    return STATUS_OK, *json_reply(tasks)
  end
  
  def show
    require_auth_level :admin, :tech, :viewer
    
    task = TaskManager.instance.get @session[:user][:name], params['task']

    return STATUS_NOT_FOUND if task.nil?
    return STATUS_OK, *json_reply(task)
  end
  
  def create
    require_auth_level :admin, :tech, :viewer
    
    task = TaskManager.instance.create @session[:user][:name]
    
    return STATUS_NOT_FOUND if task.nil?
    return STATUS_OK, *json_reply(task)
  end
  
  def destroy
    require_auth_level :admin, :tech, :viewer
    
    TaskManager.instance.delete @session[:user][:name], params['task']
    
    return STATUS_OK
  end

end

end # DB::
end # RCS::
