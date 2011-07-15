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

      alerts = user.alerts

      return RESTController.reply.ok(alerts)
    end
  end

  def show
    require_auth_level :view

    mongoid_query do
      # use reload to avoid cache
      user = @session[:user].reload

      alert = user.alerts.find(@params['_id'])

      return RESTController.reply.ok(alert)
    end
  end

  def create
    require_auth_level :view

    mongoid_query do
      user = @session[:user].reload
      na = ::Alert.new

      na.path = @params['path']
      na.evidence = @params['evidence']
      na.keywords = @params['keywords']
      na.enabled = true
      na.suppression = @params['suppression']
      na.type = @params['type']
      na.priority = @params['priority']

      user.alerts << na

      Audit.log :actor => @session[:user][:name], :action => 'alert.create', :desc => "Created one alert"

      return RESTController.reply.ok(na)
    end    
  end

  def update
    require_auth_level :view

    mongoid_query do
      user = @session[:user].reload
      alert = user.alerts.find(@params['_id'])
      @params.delete('_id')

      @params.each_pair do |key, value|
        if alert[key.to_s] != value and not key['_ids']
          Audit.log :actor => @session[:user][:name], :action => 'alert.update', :desc => "Updated '#{key}' to '#{value}' for alert #{alert[:_id]}"
        end
      end

      alert.update_attributes(@params)

      return RESTController.reply.ok(alert)
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
      
      return RESTController.reply.ok
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

      return RESTController.reply.ok(counter)
    end
  end

end

end #DB::
end #RCS::