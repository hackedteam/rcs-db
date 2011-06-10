#
# Controller for the Proxy objects
#

module RCS
module DB

class ProxyController < RESTController

  def index
    require_auth_level :server, :tech

    mongoid_query do
      result = ::Proxy.all

      return STATUS_OK, *json_reply(result)
    end
  end

  def create
    require_auth_level :admin

    result = Proxy.create(name: @params['name'], port: 4444, poll: false, configured: false, redirect: 'auto')

    Audit.log :actor => @session[:user][:name], :action => 'proxy.create', :desc => "Created the injection proxy '#{@params['name']}'"

    return STATUS_OK, *json_reply(result)
  end

  def update
    require_auth_level :admin

    mongoid_query do
      proxy = Proxy.find(params['proxy'])
      params.delete('proxy')
      return STATUS_NOT_FOUND if proxy.nil?

      params.each_pair do |key, value|
        if proxy[key.to_s] != value and not key['_ids']
          Audit.log :actor => @session[:user][:name], :action => 'proxy.update', :desc => "Updated '#{key}' to '#{value}' for injection proxy '#{proxy['name']}'"
        end
      end

      proxy.update_attributes(params)

      return STATUS_OK, *json_reply(proxy)
    end
  end

  def destroy
    require_auth_level :admin

    mongoid_query do
      proxy = Proxy.find(params['proxy'])
      proxy.destroy

      return STATUS_OK
    end
  end

  def version
    require_auth_level :server

    mongoid_query do
      proxy = Proxy.find(params['_id'])
      params.delete('_id')
      return STATUS_NOT_FOUND if proxy.nil?

      proxy.update_attributes(params)

      return STATUS_OK
    end
  end

  def config
    require_auth_level :server
    
    #TODO: implement config retrieval
    #TODO: mark as configured...

    return STATUS_NOT_FOUND
  end

  def log
    require_auth_level :server

    time = Time.parse(params['time']).getutc.to_i

    mongoid_query do
      proxy = Proxy.find(params['_id'])
      db = Mongoid.database
      coll = db['log.' + proxy[:_id].to_s]
      coll.save({time: time, type: params['type'].downcase, desc: params['desc']})

      return STATUS_OK
    end
  end

end

end #DB::
end #RCS::
