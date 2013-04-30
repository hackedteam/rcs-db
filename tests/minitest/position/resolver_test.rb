require_relative '../helper'
require_db 'position/resolver'

module RCS
module DB

  class PositionResolver
    def self.trace(a,b)
      #avoid debug messages
    end
  end

  # classes used inside resolver
  class Config
    include Singleton
    def global
      {'POSITION' => true}
    end
  end

  # fake frontend class to make the requests
  class Frontend
    def self.proxy(method, proto, host, url, content = nil, headers = {})
      port = case proto
               when 'http'
                80
               when 'https'
                443
             end
      http = Net::HTTP.new(host, port)
      http.use_ssl = (port == 443)
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      case method
        when 'GET'
          resp = http.get(url)
        when 'POST'
          resp = http.post(url, content, headers)
      end
      return resp
    end
  end

class ResolverTest < Test::Unit::TestCase

  def test_wifi_google
    wifi = [{macAddress: '00:17:C2:F8:9C:60', signalStrength: 55, ssid: 'FASTWEB-1-0017C2F89C60'},
            {macAddress: '00:25:C9:DF:AB:A7', signalStrength: 41, ssid: 'ht-guest-wifi'},
            {macAddress: '38:22:9D:F7:84:F4', signalStrength: 77, ssid: 'FASTWEB-1-38229DF784F4'},
            {macAddress: '00:1F:33:FC:B4:18', signalStrength: 85, ssid: 'NETGEAR'},
            {macAddress: '00:24:89:01:5E:0B', signalStrength: 48, ssid: 'Vodafone-10369386'},
            {macAddress: '00:1C:A2:DC:3C:B8', signalStrength: 84, ssid: 'InfostradaWifi'},
            {macAddress: '00:18:F8:7A:CA:C5', signalStrength: 81, ssid: 'prsp'},
            {macAddress: '00:25:4B:0A:63:E5', signalStrength: 80, ssid: 'Network di laura spinella'},
            {macAddress: '00:18:F8:7A:CA:C5', signalStrength: 81, ssid: 'prsp'}
           ]
    request = {'wifiAccessPoints' => wifi}

    position = PositionResolver.get(request)

    assert_true 45.47651 < position['latitude'] and position['latitude'] < 45.47655
    assert_true  9.19070 < position['longitude'] and position['longitude'] < 9.19078
    assert_true 20 < position['accuracy'] and position['accuracy'] < 100
    assert_false position['address'].nil?
  end

  def test_cell_google
    cells = [{mobileCountryCode: 222, mobileNetworkCode: 1, locationAreaCode: 61208, cellId: 528, signalStrength: -92, timingAdvance: 0, age: 0}]
    request = {'cellTowers' => cells, radioType: 'gsm'}

    position = PositionResolver.get(request)
    #expected = {"latitude"=>45.4774536, "longitude"=>9.1906932, "accuracy"=>673.0}

    assert_true 45.47745 < position['latitude'] and position['latitude'] < 45.47750
    assert_true  9.19070 < position['longitude'] and position['longitude'] < 9.19078
    assert_true 200 < position['accuracy'] and position['accuracy'] < 700
    assert_false position['address'].nil?
  end

  def test_gps_google
      request = {'gpsPosition' => {"latitude"=>45.4774536, "longitude"=>9.1906932}}
      position = PositionResolver.get(request)
      expected = "Via Fatebenesorelle, 2-14, 20121 Milan, Italy"

      assert_equal expected, position['address']['text']
  end

  def test_ip_geoip
    request = {'ipAddress' => {'ipv4' => '93.62.139.46'}}
    position = PositionResolver.get(request)
    expected = {"latitude"=>45.4667, "longitude"=>9.2, "accuracy"=>20000}

    assert_equal expected['latitude'], position['latitude']
    assert_equal expected['longitude'], position['longitude']
    assert_equal expected['accuracy'], position['accuracy']
  end

  def test_local_ip
    request = {'ipAddress' => {'ipv4' => '192.168.1.1'}}
    position = PositionResolver.get(request)
    expected = {'location' => {}, 'address' => {}}

    assert_equal expected, position
  end

=begin
  def test_navizon_cell
    request = {'navizon' => "1,222,1,61208,528,-92;"}
    position = PositionResolver.get(request)
    expected = {"latitude"=>45.4774536, "longitude"=>9.1906932, "accuracy"=>673.0}

    assert_equal expected['latitude'], position['latitude']
    assert_equal expected['longitude'], position['longitude']
    assert_equal expected['accuracy'], position['accuracy']
    assert_false position['address'].nil?
  end

  def test_navizon_wifi
    request = {'navizon' => "0,00:17:C2:F8:9C:60,-55;0,00:25:C9:DF:AB:A7,-41;0,38:22:9D:F7:84:F4,-77;0,00:1F:33:FC:B4:18,-85;0,00:24:89:01:5E:0B,-48;0,00:1C:A2:DC:3C:B8,-84;"}

    position = PositionResolver.get(request)
    expected = {"latitude"=>45.476504, "longitude"=>9.1907414, "accuracy"=>52.0}

    assert_equal expected['latitude'], position['latitude']
    assert_equal expected['longitude'], position['longitude']
    assert_equal expected['accuracy'], position['accuracy']
    assert_false position['address'].nil?
  end
=end

  def test_malformed
    request = {}
    position = PositionResolver.get(request)
    expected = {'location' => {}, 'address' => {}}

    assert_equal expected, position
  end

  def test_cache
    request = {'gpsPosition' => {"latitude"=>45.4774536, "longitude"=>9.1906932}}
    response = {'address' => {'text' => "Via Fatebenesorelle, 2-14, 20121 Milan, Italy"}}
    PositionResolver.put_cache(request, response)

    position = PositionResolver.get(request)

    assert_equal response, position
  end

end


end #DB::
end #RCS::
