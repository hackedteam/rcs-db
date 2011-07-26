require_relative '../tasks'

module RCS
module DB

class TaskController < RESTController
  
  def index
    require_auth_level :admin, :sys, :view
    
    tasks = TaskManager.instance.list @session[:user][:name]
    RESTController.reply.ok tasks
  end
  
  def show
    require_auth_level :admin, :sys, :view
    
    task = TaskManager.instance.get @session[:user][:name], @params['_id']
    return RESTController.reply.not_found if task.nil?
    return RESTController.reply.ok task
  end
  
  def create
    require_auth_level :admin, :sys, :view
    
    task = TaskManager.instance.create @session[:user][:name], @params['type'], @params['file_name']
    return RESTController.reply.bad_request if task.nil?
    puts task.inspect
    return RESTController.reply.ok task
  end
  
  def destroy
    require_auth_level :admin, :sys, :view
    
    TaskManager.instance.delete @session[:user][:name], @params['_id']
    RESTController.reply.ok
  end

end

end # DB::
end # RCS::
