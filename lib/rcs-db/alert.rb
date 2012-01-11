#
# The alerting subsystem
#

# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

class Alerting
  extend RCS::Tracer

  class << self

    def new_sync(agent)
      ::Alert.where(:enabled => true, :action => 'SYNC').each do |alert|
        # skip non matching agents
        next unless match_path(alert, agent)
        user = ::User.find(alert.user_id)
        alert_fast_queue(alert, user.contact, '', '')
      end
    end

    def new_instance(agent)
      ::Alert.where(:enabled => true, :action => 'INSTANCE').each do |alert|
        # skip non matching agents
        next unless match_path(alert, agent)
        user = ::User.find(alert.user_id)
        alert_fast_queue(alert, user.contact, '', '')
      end
    end

    def new_evidence(evidence)
      trace :debug, "ALERT: new evidence"
    end

    def failed_component(component)
      users = get_alert_users
      trace :debug, "Alerting that a component has failed: #{component.name}"
      users.each do |user|
        alert_fast_queue(nil, user.contact, "RCS Alert [monitor] ERROR", "The component '#{component.name}' has failed, please check it.")
      end
    end

    def restored_component(component)
      users = get_alert_users
      trace :debug, "Alerting that a component was restored: #{component.name}"
      users.each do |user|
        alert_fast_queue(nil, user.contact, "RCS Alert [monitor] OK", "The component '#{component.name}' is now active")
      end
    end

    private

    def get_alert_users
      ::Group.where({:alert => true}).first.users
    end

    def match_path(alert, agent)
      # the path of an agent does not include itself, add it to obtain the full path
      agent_path = agent.path << agent._id
      # check if the agent path is included in the alert path
      # this way an alert on a target will be triggered by all of its agent
      (agent_path & alert.path == alert.path)
    end

    def alert_fast_queue(alert, to, subject, body)

      #TODO: implement suppression

      trace :debug, "MAIL TO: #{to}  SUBJECT: #{subject}"
    end

  end
end

end # ::DB
end # ::RCS