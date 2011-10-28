#
# Controller for Cores
#
require 'tempfile'
require 'zip/zip'
require 'zip/zipfilesystem'

module RCS
module DB

class CoreController < RESTController

  def index
    require_auth_level :sys

    mongoid_query do
      cores = ::Core.all

      return RESTController.reply.ok(cores)
    end
  end

  def show
    require_auth_level :sys

    mongoid_query do
      core = ::Core.where({name: @params['_id']}).first
      return RESTController.reply.not_found("Core #{@params['_id']} not found") if core.nil?

      if @params['content']
        temp = GridFS.to_tmp core[:_grid].first

        list = []
        Zip::ZipFile.foreach(temp.path) do |f|
          list << {name: f.name, size: f.size, date: f.time}
        end

        return RESTController.reply.ok(list)
      else
        file = GridFS.get core[:_grid].first
        Audit.log :actor => @session[:user][:name], :action => 'core.get', :desc => "Downloaded the core #{@params['_id']}"
        return RESTController.reply.stream_grid(file)
      end
    end
  end

  def create
    require_auth_level :sys
    
    mongoid_query do
      # search if already present
      core = ::Core.where({name: @params['_id']}).first
      unless core.nil?
        GridFS.delete core[:_grid].first
        core.destroy
      end

      # replace the new one
      core = ::Core.new

      core.name = @params['_id']

      core[:_grid] = [ GridFS.put(@request[:content], {filename: @params['_id']}) ]
      core[:_grid_size] = @request[:content].bytesize
      core.save

      Audit.log :actor => @session[:user][:name], :action => 'core.replace', :desc => "Replaced the #{@params['_id']} core"

      return RESTController.reply.ok(core)
    end
  end

  def update
    require_auth_level :sys

    mongoid_query do
      core = ::Core.where({name: @params['_id']}).first
      return RESTController.reply.not_found("Core #{@params['_id']} not found") if core.nil?

      new_entry = @params['name']

      temp = GridFS.to_tmp core[:_grid].first

      Zip::ZipFile.open(temp.path) do |z|
        z.file.open(new_entry, "w") { |f| f.write @request[:content] }
      end

      content = File.open(temp.path, 'rb') {|f| f.read}

      # delete the old one
      GridFS.delete core[:_grid].first

      # replace with the new zip file
      core[:_grid] = [ GridFS.put(content, {filename: @params['_id']}) ]
      core[:_grid_size] = content.bytesize
      core.save

      Audit.log :actor => @session[:user][:name], :action => 'core.add', :desc => "Added [#{new_entry}] to the core #{core.name}"

      return RESTController.reply.ok()
    end
  end

  def destroy
    require_auth_level :sys

    mongoid_query do
      core = ::Core.where({name: @params['_id']}).first
      return RESTController.reply.not_found("Core #{@params['_id']} not found") if core.nil?

      GridFS.delete core[:_grid].first
      core.destroy

      Audit.log :actor => @session[:user][:name], :action => 'core.delete', :desc => "Deleted the core #{@params['_id']}"

      return RESTController.reply.ok()
    end
  end

  def version
    require_auth_level :sys

    mongoid_query do
      core = ::Core.where({name: @params['_id']}).first
      return RESTController.reply.not_found("Core #{@params['_id']} not found") if core.nil?

      core.version = @params['version']
      core.save

      Audit.log :actor => @session[:user][:name], :action => 'core.version', :desc => "Set the core #{@params['_id']} to version #{@params['version']}"

      return RESTController.reply.ok()
    end
  end

end

end #DB::
end #RCS::