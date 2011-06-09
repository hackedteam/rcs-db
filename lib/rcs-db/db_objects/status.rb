require 'mongoid'

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
  
  store_in :statuses

  class << self

    # updates or insert the status of a component
    def status_update(name, address, status, info, stats)

      #trace :debug, "#{name}, #{address}, #{status}, #{info}, #{stats}"

      monitor = ::Status.find_or_create_by(name: name, address: address)

      monitor[:info] = info
      monitor[:pcpu] = stats[:pcpu]
      monitor[:cpu] = stats[:cpu]
      monitor[:disk] = stats[:disk]
      monitor[:time] = Time.now.getutc.to_i
      case(status)
        when 'OK'
          monitor[:status] = OK
        when 'WARN'
          monitor[:status] = WARN
        when 'ERROR'
          monitor[:status] = ERROR
      end

      monitor.save
    end

    def status_check
      monitors = ::Status.all

      monitors.each do |m|
        # a component is marked failed after 2 minutes (if not already marked)
        if Time.now.getutc.to_i - m[:time] > 120 and m[:status] != ERROR
          m[:status] = ERROR
          # TODO: send alerting mail
          trace :warn, "Component #{m[:name]} is not responding, marking failed..."
          m.save
        end

        # check disk and CPU usage
        if m[:status] == OK and (m[:disk] <= 15 or m[:cpu] >= 85 or m[:pcpu] >= 85) then
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
