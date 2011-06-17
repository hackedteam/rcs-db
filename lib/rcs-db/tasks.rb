
require 'uuidtools'
require 'rcs-common/trace'

module RCS
module DB

class Task
  include RCS::Tracer
  
  attr_reader :_id, :total, :current, :grid_id
  
  def initialize(type, file_name)
    @_id = UUIDTools::UUID.random_create.to_s
    @file_name = file_name
    @type = type
    @current = 0
    @total = 0
    @grid_id = ''
    @file_size = 0
    @desc = 'Task fuffa'
    @stopped = false
  end
  
  def stopped?
    return @stopped
  end
  
  def stop!
    trace :debug, "Cancelling task #{@_id}"
    @stopped = true
  end

  # override this
  def perform_cycle(params)
    trace :debug, "processing #{@current} out of #{@total}"
    sleep 1
  end
  
  # override this
  def generate_output(params)
    @grid_id = '4dfa12a00afc5deb66ef3c5d' # pragmatic_agile.pdf
    #@grid_id = '4dfa1d1aa4df496c90fab43e' # underground.avi
    #@grid_id = '4dfa2483674bba48cd2a153f' # en_outlook.exe
    file = GridFS.instance.get(BSON::ObjectId.from_string(@grid_id))
    @file_size = file.file_length
    @file_name = @file_name + '.pdf'
  end
  
  def run(params)
    process = Proc.new do
      @total = rand(10) + 1
      @total.times do |n|
        break if stopped?
        perform_cycle(params)
        generate_output(params) if (@current + 1 == @total)
        @current += 1
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
  
  def create(user, type, file_name, params = {})
    @tasks[user] ||= Hash.new
    task = Task.new type, file_name
    @tasks[user][task._id] = task
    trace :debug, "Creating task #{task._id} of type #{type}for user '#{user}', saving to '#{file_name}'"
    task.run params
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
    # TODO: delete file from grid
  end
end

end # DB::
end # RCS::
