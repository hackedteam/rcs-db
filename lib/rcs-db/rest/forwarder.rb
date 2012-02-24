#
# Controller for Backups
#


module RCS
module DB

class ForwarderController < RESTController

  def index
    require_auth_level :sys

    mongoid_query do
      return ok(::Forwarder.all)
    end
  end

  def create
    require_auth_level :sys

    return conflict('LICENSE_LIMIT_REACHED') unless LicenseManager.instance.limits[:forwarders]

    mongoid_query do
      f = ::Forwarder.new
      f.enabled = @params['enabled'] == true ? true : false
      f.name = @params['name']
      f.type = @params['type'] || 'JSON'
      f.raw = @params['raw']
      f.keep = @params['keep']
      f.dest = @params['dest']
      f.path = @params['path']
      f.save
      
      Audit.log :actor => @session[:user][:name], :action => 'forwarder.create', :desc => "Forwarding rule '#{f.name}' was created"

      return ok(f)
    end    
  end

  def update
    require_auth_level :sys

    mongoid_query do
      forwarder = ::Forwarder.find(@params['_id'])
      @params.delete('_id')

      @params.each_pair do |key, value|
        if forwarder[key.to_s] != value
          Audit.log :actor => @session[:user][:name], :action => 'forwarder.update', :desc => "Updated '#{key}' to '#{value}' for forwarding rule #{forwarder[:name]}"
        end
      end

      forwarder.update_attributes(@params)

      return ok(forwarder)
    end
  end

  def destroy
    require_auth_level :sys

    mongoid_query do
      forwarder = ::Forwarder.find(@params['_id'])
      Audit.log :actor => @session[:user][:name], :action => 'forwarder.destroy', :desc => "Deleted the forwarding rule [#{forwarder[:name]}]"
      forwarder.destroy

      return ok
    end
  end

end

end #DB::
end #RCS::