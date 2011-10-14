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
      nc = ::Status.where({nc: true}).first

      return if nc.nil?

      trace :info, "NetworkController: Pushing configuration to #{address}"

      # send the push request
      http = Net::HTTP.new(nc.address, 80)
      resp = http.request_put("/RCS-NC_#{address}", '', {})
      
    rescue Exception => e
      trace :error, "NetworkController: #{e.message}"
    end

  end
  
end

end #DB::
end #RCS::