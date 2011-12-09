require_relative '../tasks'

module RCS
module DB

class TaskController < RESTController
  
  def index
    require_auth_level :admin, :sys, :tech, :view
    
    tasks = TaskManager.instance.list @session[:user][:name]
    ok tasks
  end
  
  def show
    require_auth_level :admin, :sys, :tech, :view
    
    task = TaskManager.instance.get @session[:user][:name], @params['_id']
    return not_found if task.nil?
    return ok task
  end
  
  def create
    require_auth_level :admin, :sys, :tech, :view
    
    task = TaskManager.instance.create @session[:user][:name], @params['type'], @params['file_name']
    return bad_request if task.nil?
    return ok task
  end
  
  def destroy
    require_auth_level :admin, :sys, :tech, :view
    
    TaskManager.instance.delete @session[:user][:name], @params['_id']
    ok
  end

end

end # DB::
end # RCS::
