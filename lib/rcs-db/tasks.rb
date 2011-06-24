require 'archive/tar/minitar'
require 'uuidtools'
require 'rcs-common/trace'
require 'rcs-common/temporary'

module RCS
module DB

class TarGzCompression
  include Archive::Tar
  
  def initialize(fd)
    sgz = Zlib::GzipWriter.new(fd)
    @tar = Minitar::Output.new(sgz)
  end
  
  def add_stream(entry, string)
    Minitar::pack_stream(entry, StringIO.new(string), @tar)
  end
  
  def add_file(entry)
    Minitar::pack_file(entry, @tar)
  end
  
  def close
    @tar.close
  end
end

class DummyGenerator
  def total
    100
  end
  
  def description
    @description || 'Dummy Generator'
  end
  
  def next_entry
    100.times do |n|
      filename = "dummy#{n}.txt"
      @description = "generating '#{filename}'"
      content = @description + " ciccio pasticcio 123"
      yield 'stream', filename, content
    end
  end
end

class Task
  include RCS::Tracer
  
  attr_reader :_id, :total, :current, :grid_id, :desc, :type, :file_name, :file_size
  
  def initialize(type, file_name, params = {})
    @_id = UUIDTools::UUID.random_create.to_s
    @file_name = file_name
    @type = type
    @current = 0
    @desc = ''
    @grid_id = ''
    @stopped = false
    @generator = Task.generator_class.new(params)
    @total = @generator.total
  end
  
  def self.generator_class
    @generator_class || eval("#{@type}Generator")
  end
  
  def self.compressor_class
    @compressor_class || TarGzCompression
  end
  
  def self.digest_class
    @digest_class || Digest::SHA1
  end
  
  def sha1(file)
    Task.digest_class.new.file(file).hexdigest
  end
    
  def step
    @current += 1
  end
  
  def stopped?
    @stopped
  end
  
  def stop!
    trace :info, "cancelling task #{@_id}"
    @stopped = true
  end
  
  def run
    process = Proc.new do
      
      # temporary file is our task id
      begin
        tmpfile = Temporary.file('temp', @_id)
        compressor = Task.compressor_class.new tmpfile
        @generator.next_entry do |type, entry, content|
          
          break if stopped?
          
          @desc = @generator.description
          case type
            when 'stream'
              compressor.add_stream entry, content
            when 'file'
              compressor.add_file entry
          end
          step
        end
      ensure
        compressor.close
      end
      
      @grid_id = @_id
    end # process
    
    EM.defer process
  end
end # Task

class TaskManager
  include Singleton
  include RCS::Tracer
  
  def initialize
    @tasks = Hash.new
    Task.instance_eval { @generator_class = DummyGenerator }
  end
  
  def create(user, type, file_name, params = {})
    @tasks[user] ||= Hash.new
    task = Task.new type, file_name, params
    trace :debug, "Creating task #{task._id} of type #{type}for user '#{user}', saving to '#{file_name}'"
    task.run
    @tasks[user][task._id] = task
    task
  end
  
  def get(user, id)
    trace :debug, "Getting task #{id} for user '#{user}'"
    @tasks[user][id] rescue nil
  end
  
  def list(user)
    trace :debug, "List of tasks for user '#{user}': #{@tasks[user]}"
    
    tasks = @tasks[user]
    tasks ||= {}
    
    tasks.values
  end

  # TODO: delete temporary file
  def delete(user, task_id)
    trace :info, "Deleting task #{task_id} for user '#{user}'"
    task = @tasks[user][task_id]
    task.stop!
    @tasks[user].delete task_id
    # TODO: delete file
  end
end # TaskManager

end # DB::
end # RCS::
