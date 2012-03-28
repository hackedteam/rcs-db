require 'mongoid'

require_relative 'alert'
require_relative '../audit'

require_relative '../push'

#module RCS
#module DB

class Status
  include Mongoid::Document
  include Mongoid::Timestamps
  extend RCS::Tracer
  
  OK = '0'
  WARN = '1'
  ERROR = '2'

  field :name, type: String
  field :status, type: String
  field :address, type: String
  field :info, type: String
  field :time, type: Integer
  field :pcpu, type: Integer
  field :cpu, type: Integer
  field :disk, type: Integer
  field :type, type: String
  
  store_in :statuses

  class << self

    # updates or insert the status of a component
    def status_update(name, address, status, info, stats, type)

      #trace :debug, "#{name}, #{address}, #{status}, #{info}, #{stats}"

      monitor = ::Status.find_or_create_by(name: name, address: address)

      monitor[:info] = info
      monitor[:pcpu] = stats[:pcpu]
      monitor[:cpu] = stats[:cpu]
      monitor[:disk] = stats[:disk]
      monitor[:time] = Time.now.getutc.to_i
      monitor[:type] = type

      # check the low resource conditions
      if (status == 'OK' and (monitor[:disk] <= 15 or monitor[:cpu] >= 85 or monitor[:pcpu] >= 85))
        status = 'WARN'
      end

      case(status)
        when 'OK'
          # notify the restoration of a component
          if monitor[:status] == ERROR
            RCS::DB::Alerting.restored_component(monitor)
            RCS::DB::Audit.log :actor => '<system>', :action => 'alert', :desc => "Component #{monitor[:name]} was restored to normal status"
          end
          monitor[:status] = OK
        when 'WARN'
          monitor[:status] = WARN
        when 'ERROR'
          monitor[:status] = ERROR
      end

      monitor.save

      # notify all that the monitor has changed
      RCS::DB::PushManager.instance.notify('monitor')
    end

    def status_check
      monitors = ::Status.all

      monitors.each do |m|
        # a component is marked failed after 2 minutes (if not already marked)
        if Time.now.getutc.to_i - m[:time] > 120 and m[:status] != ERROR
          m[:status] = ERROR
          trace :warn, "Component #{m[:name]} is not responding, marking failed..."
          RCS::DB::Audit.log :actor => '<system>', :action => 'alert', :desc => "Component #{m[:name]} is not responding, marking failed..."
          m.info = 'Not sending status update for more than 2 minutes'
          m.save
          # notify the alerting system
          RCS::DB::Alerting.failed_component(m)
        end

        # check disk and CPU usage
        if m[:status] == OK and (m[:disk] <= 15 or m[:cpu] >= 85 or m[:pcpu] >= 85)
          m[:status] = WARN
          trace :warn, "Component #{m[:name]} has low resources, raising a warning..."
          m.save
        end
      end
    end
  end

end

#end # ::DB
#end # ::RCS
