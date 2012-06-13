require_relative '../tasks'

module RCS
module DB

class TaskController < RESTController
  
  def index
    require_auth_level :admin, :sys, :tech, :view
    
    tasks = TaskManager.instance.list @session[:user]
    ok tasks
  end
  
  def show
    require_auth_level :admin, :sys, :tech, :view
    
    task = TaskManager.instance.get @session[:user], @params['_id']
    
    return not_found if task.nil?
    return ok task
  end
  
  def create
    require_auth_level :admin, :sys, :tech, :view

    task = TaskManager.instance.create @session[:user], @params['type'], @params['file_name'], @params['params']
    
    return bad_request if task.nil?
    return ok task
  end
  
  def destroy
    require_auth_level :admin, :sys, :tech, :view

    TaskManager.instance.delete @session[:user], @params['_id']

    return ok
  end

  def download
    require_auth_level :admin, :sys, :tech, :view

    path, callback = TaskManager.instance.download @session[:user], @params['_id']

    return bad_request if path.nil?
    return stream_file(path, callback)
  end

end

end # DB::
end # RCS::
