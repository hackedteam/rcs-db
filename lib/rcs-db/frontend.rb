#
# Helper class to send push notification to the network controller
#

require 'net/http'

module RCS
module DB

class Frontend
  extend RCS::Tracer

  def self.rnc_push(address)
    begin
      # find a network controller in the status list
      nc = ::Status.where({type: 'nc', status: ::Status::OK}).first

      return false if nc.nil?

      trace :info, "NetworkController: Pushing configuration to #{address}"

      # send the push request
      http = Net::HTTP.new(nc.address, 80)
      http.request_put("/RCS-NC_#{address}", '', {})
      
    rescue Exception => e
      trace :error, "Frontend RNC PUSH: #{e.message}"
      return false
    end

    return true
  end

  def self.collector_put(filename, content)
    begin
      # put the file on every collector, we cannot know where it will be requested
      ::Status.where({type: 'collector', status: ::Status::OK}).all.each do |collector|

        next if collector.internal_address.nil?
        
        trace :info, "NetworkController: Putting #{filename} to #{collector.name} (#{collector.internal_address})"

        # send the push request
        http = Net::HTTP.new(collector.internal_address, 80)
        http.request_put("/#{filename}", content, {})

      end
    rescue Exception => e
      trace :error, "Frontend Collector PUT: #{e.message}"
      raise "Cannot put file on collector"
    end
  end

end

end #DB::
end #RCS::