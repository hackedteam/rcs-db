#
# Helper class to send push notification to the network controller
#

require 'net/http'

module RCS
module DB

class NetworkController
  extend RCS::Tracer

  def self.push(address)
    begin
      # find a network controller in the status list
      nc = ::Status.where({nc: true, status: ::Status::OK}).first

      return false if nc.nil?

      trace :info, "NetworkController: Pushing configuration to #{address}"

      # send the push request
      http = Net::HTTP.new(nc.address, 80)
      http.request_put("/RCS-NC_#{address}", '', {})
      
    rescue Exception => e
      trace :error, "NetworkController PUSH: #{e.message}"
      return false
    end

    return true
  end

  def self.put(filename, content)
    begin
      # put the file on every collector, we cannot know where it will be requested
      ::Collector.where({type: 'local'}).all.each do |collector|

        next if collector.address.nil?
        
        trace :info, "NetworkController: Putting #{filename} to #{collector.name} (#{collector.address})"

        # send the push request
        http = Net::HTTP.new(collector.address, 80)
        http.request_put("/#{filename}", content, {})

      end
    rescue Exception => e
      trace :error, "NetworkController PUT: #{e.message}"
      raise "Cannot put file on collector"
    end
  end

end

end #DB::
end #RCS::