#
# The alerting subsystem
#

# from RCS::Common
require 'rcs-common/trace'

require 'net/smtp'

module RCS
module DB

class Alerting
  extend RCS::Tracer

  class << self

    def new_sync(agent)
      ::Alert.where(:enabled => true, :action => 'SYNC').each do |alert|
        # skip non matching agents
        next unless match_path(alert, agent)

        alert.logs.create!(time: Time.now.getutc.to_i, path: agent.path + [agent._id]) unless alert.type == 'NONE'

        if alert.type == 'MAIL'
          # put the matching alert in the queue
          user = ::User.find(alert.user_id)
          alert_fast_queue(to: user.contact, subject: 'RCS Alert [SYNC]', body: "The agent #{agent.name} has synchronized on #{Time.now}")
        end
      end
    end

    def new_instance(agent)
      ::Alert.where(:enabled => true, :action => 'INSTANCE').each do |alert|
        # skip non matching agents
        next unless match_path(alert, agent)

        alert.logs.create!(time: Time.now.getutc.to_i, path: agent.path + [agent._id]) unless alert.type == 'NONE'
        
        if alert.type == 'MAIL'
          # put the matching alert in the queue
          user = ::User.find(alert.user_id)
          alert_fast_queue(to: user.contact, subject: 'RCS Alert [INSTANCE]', body: "A new instance of #{agent.ident} has been created on #{Time.now}.\r\n Its name is: #{agent.name}")
        end
      end
    end

    def new_evidence(evidence)
      ::Alert.where(:enabled => true, :action => 'EVIDENCE').each do |alert|
        agent = ::Item.find(evidence.agent_id.first)
        # skip non matching agents
        next unless match_path(alert, agent)
        # skip non matching evidence type
        next unless (alert.evidence == '*' or alert.evidence == evidence.type)
        # skip if none of the values in the "data" match the keywords
        next if evidence.data.values.select {|v| v =~ Regexp.new(alert.keywords)}.empty?

        # save the relevance tag into the evidence
        evidence.rel = alert.tag
        evidence.save

        # if we don't want to be alerted, don't insert in the queue
        return if alert.type == 'NONE'

        # put the matching alert in the queue the suppression will be done there
        # and the mail will be sent accordingly to the 'type' of alert
        user = ::User.find(alert.user_id)
        alert_fast_queue(alert: alert, evidence: evidence._id, path: evidence.path,
                         to: user.contact,
                         subject: 'RCS Alert [EVIDENCE]',
                         body: "An evidence matching this alert [#{agent.name} #{alert.evidence} #{alert.keywords}] has arrived into the system.")
      end
    end

    def failed_component(component)
      get_alert_users.each do |user|
        alert_fast_queue(to: user.contact, subject: "RCS Alert [monitor] ERROR", body: "The component '#{component.name}' has failed, please check it.")
      end
    end

    def restored_component(component)
      get_alert_users.each do |user|
        alert_fast_queue(to: user.contact, subject: "RCS Alert [monitor] OK", body: "The component '#{component.name}' is now active")
      end
    end

    private

    def get_alert_users
      group = ::Group.where({:alert => true}).first
      return group ? group.users : []
    end

    def match_path(alert, agent)
      # empty alert path means everything
      return true if alert.path.empty?
      
      # the path of an agent does not include itself, add it to obtain the full path
      agent_path = agent.path + [agent._id]

      # check if the agent path is included in the alert path
      # this way an alert on a target will be triggered by all of its agent
      (agent_path & alert.path == alert.path)
    end

    def alert_fast_queue(params)
      # no license, no alerts :)
      return unless LicenseManager.instance.check :alerting
      begin
        # insert the entry in the queue.
        # the alert thread will take care of it (suppressing it if needed)
        ::AlertQueue.create! do |aq|
          aq.alert = [params[:alert]._id] if params[:alert]
          aq.evidence = [params[:evidence]._id] if params[:evidence]
          aq.path = params[:path]
          aq.to = params[:to]
          aq.subject = params[:subject]
          aq.body = params[:body]
        end
      rescue Exception => e
        trace :error, "Cannot queue alert: #{e.message}"
        trace :fatal, "EXCEPTION: [#{e.class}] " << e.backtrace.join("\n")
      end
    end

    def clean_old_alerts
      # delete the alerts older than a week
      ::Alert.all.each do |alert|
        alert.logs.destroy_all(conditions: { :time.lt => Time.now.getutc.to_i - 86400*7 })
      end
    end

    public

    # this method runs in a proc triggered by the mail event loop every 5 seconds
    # we are inside the thread pool, so we can be slow...
    def dispatch
      # no license, no alerts :)
      return unless LicenseManager.instance.check :alerting

      begin
        alerts = ::AlertQueue.all

        # remove too old alerts to keep it clean
        clean_old_alerts

        return unless alerts.count != 0

        trace :info, "Processing alert queue (#{alerts.count})..."

        alerts.each do |aq|
          if aq.alert and aq.evidence
            alert = ::Alert.find(aq.alert.first)

            # check if we are in the suppression timeframe
            if Time.now.getutc.to_i - alert.last > alert.suppression
              # we are out of suppression, create a new entry and mail
              trace :debug, "Triggering alert: #{alert._id}"
              alert.logs.create!(time: Time.now.getutc.to_i, path: aq.path, evidence: aq.evidence)
              alert.last = Time.now.getutc.to_i
              alert.save
              send_mail(aq.to, aq.subject, aq.body) if alert.type == 'MAIL'
            else
              trace :debug, "Triggering alert: #{alert._id} (suppressed)"
              al = alert.logs.last
              al.evidence << aq.evidence
              al.save
            end
          else
            # for queued items without an associated alert, send the mail
            send_mail(aq.to, aq.subject, aq.body)
          end
          aq.destroy
        end
      rescue Exception => e
        trace :error, "Cannot dispatch alerts: #{e.message}"
        trace :fatal, "EXCEPTION: [#{e.class}] " << e.backtrace.join("\n")
      end
    end

    def send_mail(to, subject, body)

      if Config.instance.global['SMTP'].nil?
        trace :warn, "Cannot send mail since the SMTP is not configured"
        return
      end
      
      host, port = Config.instance.global['SMTP'].split(':')
      
      trace :info, "Sending alert mail to: #{to}"

msgstr = <<-END_OF_MESSAGE
From: RCS Alert <#{Config.instance.global['SMTP_FROM']}>
To: #{to}
Subject: #{subject}
Date: #{Time.now}

#{body}
END_OF_MESSAGE

      Net::SMTP.start(host, port) do |smtp|
        smtp.send_message msgstr, Config.instance.global['SMTP_FROM'], to
      end
    rescue Exception => e
      trace :error, "Cannot send mail: #{e.message}"
      trace :fatal, "EXCEPTION: [#{e.class}] " << e.backtrace.join("\n")
    end
  
  end
end

end # ::DB
end # ::RCS