#
# Controller for Alerts
#


module RCS
module DB

class AlertController < RESTController

  def index
    require_auth_level :view

    mongoid_query do
      # use reload to avoid cache
      user = @session[:user].reload

      alerts = user.alerts.asc(:_id)
      
      return ok(alerts)
    end
  end

  def show
    require_auth_level :view

    mongoid_query do
      # use reload to avoid cache
      user = @session[:user].reload

      alert = user.alerts.find(@params['_id'])

      return ok(alert)
    end
  end

  def create
    require_auth_level :view

    return conflict('LICENSE_LIMIT_REACHED') unless LicenseManager.instance.check :alerting

    mongoid_query do
      user = @session[:user].reload
      na = ::Alert.new

      na.path = @params['path'].collect! {|x| BSON::ObjectId(x)} if @params['path'].class == Array
      na.action = @params['action']
      na.evidence = @params['evidence']
      na.keywords = @params['keywords']
      na.enabled = @params['enabled']
      na.suppression = @params['suppression']
      na.type = @params['type']
      na.tag = @params['tag']

      user.alerts << na

      Audit.log :actor => @session[:user][:name], :action => 'alert.create', :desc => "Created one alert"

      return ok(na)
    end    
  end

  def update
    require_auth_level :view

    return conflict('LICENSE_LIMIT_REACHED') unless LicenseManager.instance.check :alerting

    mongoid_query do
      user = @session[:user].reload
      alert = user.alerts.find(@params['_id'])
      @params.delete('_id')

      @params.each_pair do |key, value|
        if key == 'path'
          value.collect! {|x| BSON::ObjectId(x)} 
        end
        if alert[key.to_s] != value and not key['_ids']
          Audit.log :actor => @session[:user][:name], :action => 'alert.update', :desc => "Updated '#{key}' to '#{value}' for alert #{alert[:_id]}"
        end
      end

      alert.update_attributes(@params)

      return ok(alert)
    end
  end

  def destroy
    require_auth_level :view
    
    mongoid_query do
      user = @session[:user].reload
      alert = user.alerts.find(@params['_id'])
      Audit.log :actor => @session[:user][:name], :action => 'alert.destroy', :desc => "Deleted the alert #{alert[:_id]}"
      alert.destroy

      user.reload

      PushManager.instance.notify('alert', {rcpt: @session[:user][:_id]})

      return ok
    end
  end

    # returns the counters grouped by status
  def counters
    require_auth_level :view

    counter = 0

    mongoid_query do
      user = @session[:user].reload
      alert = user.alerts.all

      alert.each do |a|
        counter += a.logs.length
      end

      return ok(counter)
    end
  end

  def destroy_log
    require_auth_level :view

    mongoid_query do
      user = @session[:user].reload
      alert = user.alerts.find(@params['_id'])

      alert.logs.destroy_all(conditions: {_id: @params['log']['_id']})
      PushManager.instance.notify('alert', {rcpt: @session[:user][:_id]})

      return ok
    end
  end

  def destroy_all_logs
    require_auth_level :view

    mongoid_query do
      user = @session[:user].reload
      alert = user.alerts.find(@params['_id'])
      
      alert.logs.destroy_all
      PushManager.instance.notify('alert', {rcpt: @session[:user][:_id]})

      return ok
    end
  end

end

end #DB::
end #RCS::