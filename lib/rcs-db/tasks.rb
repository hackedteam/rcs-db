
require 'guid'
require 'rcs-common/trace'

module RCS
module DB

class Task
  include RCS::Tracer
  
  attr_reader :_id, :total, :current, :grid_id
  
  def initialize
    @_id = Guid.new.to_s
    @type = 'generic'
    @current = 0
    @total = 0
    @desc = description()
    @grid_id = ''
    @stopped = false
  end
  
  def description
    'Generic task'
  end
  
  def stopped?
    return @stopped
  end
  
  def stop!
    trace :debug, "Cancelling task #{@_id}"
    @stopped = true
  end
  
  def run(params)
    process = Proc.new do
      @total = rand(10) + 1
      @total.times do |n|
        break if stopped?
        @current += 1
        trace :debug, "processing #{@current} out of #{@total}"
        sleep 1
      end
      trace :debug, "process ended"
    end
    
    EM.defer process
  end
end

class TaskManager
  include Singleton
  include RCS::Tracer
  
  def initialize
    @tasks = Hash.new
  end
  
  def create(user, params = {})
    @tasks[user] ||= Hash.new
    (task = Task.new).run params
    trace :debug, "Creating task #{task._id} for user '#{user}'"
    @tasks[user][task._id] = task
    return task
  end
  
  def get(user, id)
    trace :debug, "Getting task #{id} for user '#{user}'"
    return @tasks[user][id]
  end
  
  def list(user)
    trace :debug, "List of tasks for user '#{user}': #{@tasks[user]}"
    
    tasks = @tasks[user]
    tasks ||= {}
    
    return tasks.values
  end
  
  def delete(user, task_id)
    trace :info, "Deleting task #{task_id} for user '#{user}'"
    task = @tasks[user][task_id]
    task.stop!
    @tasks[user].delete task_id
  end
end

end # DB::
end # RCS::
