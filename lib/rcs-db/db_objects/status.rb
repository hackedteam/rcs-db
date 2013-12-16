require 'mongoid'
require_relative 'alert'
require_relative '../audit'
require_relative '../push'

class Status
  include Mongoid::Document
  include Mongoid::Timestamps
  extend RCS::Tracer
  include RCS::Tracer

  OK = '0'
  WARN = '1'
  ERROR = '2'

  STATUS_CODE = {'OK' => OK, 'WARN' => WARN, 'ERROR' => ERROR}

  field :name, type: String
  field :status, type: String
  field :address, type: String
  field :info, type: String
  field :time, type: Integer
  field :pcpu, type: Integer
  field :cpu, type: Integer
  field :disk, type: Integer
  field :type, type: String
  field :version, type: String

  index({name: 1}, {background: true})
  index({address: 1}, {background: true})
  index({status: 1}, {background: true})

  store_in collection: 'statuses'

  after_save :notify, if: :status_changed?

  def ok?
    status == OK
  end

  def error?
    status == ERROR
  end

  def stats?
    cpu and pcpu and disk
  end

  def status_changed?
    changed_attributes.has_key?('status')
  end

  def low_resources?
    return false unless stats?
    disk <= 15 or cpu >= 85 or pcpu >= 85
  end

  def unupdated?
    Time.now.getutc.to_i - time > 120
  end

  def old_component?
    if type == 'anonymizer' or type == 'injector'
      false
    else
      version != $version
    end
  end

  def notify
    RCS::DB::PushManager.instance.notify('monitor')
  end

  def alert_restored
    RCS::DB::Audit.log(actor: '<system>', action: 'alert', desc: "Component #{name} was restored to normal status")
    RCS::DB::Alerting.restored_component(self)
  end

  def alert_failed
    RCS::DB::Audit.log(actor: '<system>', action: 'alert', desc: "Component #{name} is not responding, marking failed...")
    RCS::DB::Alerting.failed_component(self)
  end

  def check
    return if error?

    if unupdated?
      trace :warn, "Component #{name} (#{address}) is not responding, marking failed..."
      alert_failed
      update_attributes(status: ERROR, info: 'Not sending status update for more than 2 minutes')
    elsif old_component?
      trace :warn, "Component #{name} has version #{version}, should be #{$version}"
      update_attributes(status: ERROR, info: "Component version is #{version}, should be #{$version}")
    elsif ok? and low_resources?
      trace :warn, "Component #{name} has low resources, raising a warning..."
      update_attributes(status: WARN)
    end
  end

  def self.status_update(name, address, status, info, stats, type, version)
    monitor = find_or_create_by(name: name, address: address)

    monitor[:info] = info
    monitor[:pcpu] = stats[:pcpu]
    monitor[:cpu] = stats[:cpu]
    monitor[:disk] = stats[:disk]
    monitor[:time] = Time.now.getutc.to_i
    monitor[:type] = type
    monitor[:version] = version

    # Maybe the component is telling to rcs-db that is running ok but
    # the db know that it outdated so...
    if monitor.old_component?
      monitor[:status] = ERROR
      monitor[:info] = "Component version is #{version}, should be #{$version}"
      monitor.save!

      return
    end

    if (Integer(status) rescue nil)
      status = status.to_s
    else
      status = STATUS_CODE[status]
    end

    # check the low resource conditions
    status = WARN if status == OK and monitor.low_resources?

    # notify the restoration of a component
    monitor.alert_restored if monitor[:status] == ERROR and status == OK

    monitor[:status] = status
    monitor.save!
  end

  def self.status_check
    all.each { |status| status.check }
  end
end
