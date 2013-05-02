#
# The alerting subsystem
#

require_relative 'push'

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

        # we MUST not dispatch alert for element that are not accessible by the user
        user = ::User.find(alert.user_id)
        next unless agent.users.include? user

        unless alert.type == 'NONE'
          alert.logs.create!(time: Time.now.getutc.to_i, path: agent.path + [agent._id])
          PushManager.instance.notify('alert', {id: agent._id, rcpt: user[:_id]})
        end

        if alert.type == 'MAIL'
          # put the matching alert in the queue
          ::AlertQueue.add(to: user.contact, subject: 'RCS Alert [SYNC]', body: "The agent #{agent.name} has synchronized on #{Time.now}")
        end
      end
    rescue Exception => e
      trace :warn, "Cannot handle alert (new_sync): #{e.message}"
      trace :fatal, "EXCEPTION: " + e.backtrace.join("\n")
    end

    def new_instance(agent)
      ::Alert.where(:enabled => true, :action => 'INSTANCE').each do |alert|

        #find its factory
        factory = ::Item.where({ident: agent.ident, _kind: 'factory'}).first

        # skip non matching agents
        next unless match_path(alert, agent) || match_path(alert, factory)

        # we MUST not dispatch alert for element that are not accessible by the user
        user = ::User.find(alert.user_id)
        next unless agent.users.include? user

        unless alert.type == 'NONE'
          alert.logs.create!(time: Time.now.getutc.to_i, path: agent.path + [agent._id])
          PushManager.instance.notify('alert', {id: agent._id, rcpt: user[:_id]})
        end

        if alert.type == 'MAIL'
          # put the matching alert in the queue
          ::AlertQueue.add(to: user.contact, subject: 'RCS Alert [INSTANCE]', body: "A new instance of #{agent.ident} has been created on #{Time.now}.\r\n Its name is: #{agent.name}")
        end
      end
    rescue Exception => e
      trace :warn, "Cannot handle alert (new_instance): #{e.message}"
      trace :fatal, "EXCEPTION: " + e.backtrace.join("\n")
    end

    def new_evidence(evidence)
      ::Alert.where(:enabled => true, :action => 'EVIDENCE').each do |alert|
        agent = ::Item.where({_id: evidence.aid, _kind: 'agent'}).first

        # not found
        next if agent.nil?

        # skip non matching agents
        next unless match_path(alert, agent)

        # skip non matching evidence type
        next unless (alert.evidence == '*' or alert.evidence == evidence.type)

        # skip if none of the values in the "data" match the keywords
        next if evidence.data.values.select {|v| v =~ Regexp.new(alert.keywords, true)}.empty?

        # we MUST not dispatch alert for element that are not accessible by the user
        user = ::User.find(alert.user_id)
        next unless agent.users.include? user

        # save the relevance tag into the evidence
        if evidence.rel < alert.tag
          evidence.rel = alert.tag
          evidence.save
        end

        # if we don't want to be alerted, don't insert in the queue
        next if alert.type == 'NONE'

        # put the matching alert in the queue the suppression will be done there
        # and the mail will be sent accordingly to the 'type' of alert
        # complete the path of the evidence (operation + target + agent)
        path = agent.path + [Moped::BSON::ObjectId.from_string(evidence.aid)]

        # insert in the list of alert processing
        ::AlertQueue.add(alert: alert, evidence: evidence, path: path,
                         to: user.contact,
                         subject: 'RCS Alert [EVIDENCE]',
                         body: "An evidence matching this alert [#{agent.name} #{alert.evidence} #{alert.keywords}] has arrived into the system.")
      end
    rescue Exception => e
      trace :warn, "Cannot handle alert (new_evidence): #{e.message}"
      trace :fatal, "EXCEPTION: " + e.backtrace.join("\n")
    end

    def new_link(entities)
      ::Alert.where(:enabled => true, :action => 'LINK').each do |alert|
        # skip non matching entities
        next unless match_path(alert, entities.first)
        next unless match_path(alert, entities.last)

        # we MUST not dispatch alert for element that are not accessible by the user
        user = ::User.find(alert.user_id)
        next unless entities.first.users.include? user
        next unless entities.last.users.include? user

        # if two entities where specified, check that at list one of them is in the alert
        if not alert.entities.empty?
          alert_ent = alert.entities
          case alert_ent.size
            when 1
              next if not alert_ent.include? entities.first._id and not alert_ent.include? entities.last._id
            when 2
              next unless alert_ent.include? entities.first._id
              next unless alert_ent.include? entities.last._id
          end
        end

        unless alert.type == 'NONE'
          alert.logs.create!(time: Time.now.getutc.to_i, path: entities.first.path, entities: [entities.first._id, entities.last._id])
          PushManager.instance.notify('alert', {id: entities.first._id, rcpt: user[:_id]})
          PushManager.instance.notify('alert', {id: entities.last._id, rcpt: user[:_id]})
        end

        # update the relevance of the link
        LinkManager.instance.edit_link(from: entities.first, to: entities.last, rel: alert.tag) unless alert.tag.eql? 0

        if alert.type == 'MAIL'
          # put the matching alert in the queue
          ::AlertQueue.add(to: user.contact, subject: 'RCS Alert [LINK]', body: "A new link between '#{entities.first}' and '#{entities.last}' has been created on #{Time.now}.")
        end
      end

    rescue Exception => e
      trace :warn, "Cannot handle alert (new_link): #{e.message}"
      trace :fatal, "EXCEPTION: " + e.backtrace.join("\n")
    end

    def new_entity(entity)
      ::Alert.where(:enabled => true, :action => 'ENTITY').each do |alert|
        # skip non matching entities
        next unless match_path(alert, entity)

        # we MUST not dispatch alert for element that are not accessible by the user
        user = ::User.find(alert.user_id)
        next unless entity.users.include? user

        unless alert.type == 'NONE'
          alert.logs.create!(time: Time.now.getutc.to_i, path: entity.path, entities: [entity._id])
          PushManager.instance.notify('alert', {id: entity._id, rcpt: user[:_id]})
        end

        if alert.type == 'MAIL'
          # put the matching alert in the queue
          ::AlertQueue.add(to: user.contact, subject: 'RCS Alert [ENTITY]', body: "A new entity #{entity.name} has been created on #{Time.now}.")
        end
      end
    rescue Exception => e
      trace :warn, "Cannot handle alert (new_link): #{e.message}"
      trace :fatal, "EXCEPTION: " + e.backtrace.join("\n")
    end

    def failed_component(component)
      get_alert_users.each do |user|
        ::AlertQueue.add(to: user.contact, subject: "RCS Alert [monitor] ERROR", body: "The component '#{component.name}' has failed, please check it.")
      end
    end

    def restored_component(component)
      get_alert_users.each do |user|
        ::AlertQueue.add(to: user.contact, subject: "RCS Alert [monitor] OK", body: "The component '#{component.name}' is now active")
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

    public

    # this method runs in a proc triggered by the mail event loop every 5 seconds
    # we are inside the thread pool, so we can be slow...
    def dispatcher
      # no license, no alerts :)
      return unless LicenseManager.instance.check :alerting

      last = nil

      # infinite processing loop
      loop do
        begin
          if (queued = AlertQueue.get_queued)
            entry = queued.first
            count = queued.last

            trace :info, "#{count} alerts to be processed in queue"

            if entry.alert and entry.evidence
              alert = ::Alert.find(entry.alert.first)
              user = ::User.find(alert.user_id)

              # check if we are in the suppression timeframe
              if alert.last.nil? or Time.now.getutc.to_i - alert.last > alert.suppression or alert.logs.empty?
                # we are out of suppression, create a new entry and mail
                trace :debug, "Triggering alert: #{alert._id}"
                alert.logs.create!(time: Time.now.getutc.to_i, path: entry.path, evidence: entry.evidence)
                alert.last = Time.now.getutc.to_i
                alert.save
                # notify the console of the new alert
                PushManager.instance.notify('alert', {id: entry.path.last, rcpt: user[:_id]})
                send_mail(entry.to, entry.subject, entry.body) if alert.type == 'MAIL'
              else
                trace :debug, "Triggering alert: #{alert._id} (suppressed)"
                al = alert.logs.last
                al.evidence += entry.evidence unless al.evidence.include? entry.evidence
                al.save
                # notify even if suppressed so the console will reload the alert log list
                PushManager.instance.notify('alert', {id: entry.path.last, rcpt: user[:_id]})
              end
            else
              # for queued items without an associated alert, send the mail
              send_mail(entry.to, entry.subject, entry.body)
            end
          else
            # Nothing to do, waiting...
            sleep 1

            now = Time.now
            last ||= now

            # remove alerts too old to keep it clean (perform housekeeping every 10 minutes)
            if now - last > 600
              last = now
              Alert.destroy_old_logs
            end
          end
        rescue Exception => e
          trace :warn, "Cannot process alert queue: #{e.message}"
          trace :fatal, "EXCEPTION: [#{e.class}] " << e.backtrace.join("\n")
        end
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

      auth = Config.instance.global['SMTP_AUTH'] ? Config.instance.global['SMTP_AUTH'].to_sym : nil

      Net::SMTP.start(host, port, Config.instance.global['CN'],
                                  Config.instance.global['SMTP_USER'],
                                  Config.instance.global['SMTP_PASS'],
                                  auth) do |smtp|
        # send the message
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