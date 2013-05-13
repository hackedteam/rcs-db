require 'spec_helper'
require_db 'position/resolver'

module RCS
module DB

describe PositionResolver do

  # fake frontend class to make the requests
  class FakeFrontend
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

  before do
    PositionResolver.stub(:position_enabled?).and_return true
    # this is a development key (used for test: 100 query each day)
    PositionResolver.stub(:google_api_key).and_return 'AIzaSyAmG3O2wuA9Hj2L5an-ofRndUwVSrqElLM'

    Frontend.stub(:proxy) do |method, proto, host, url, content, headers|
      FakeFrontend.proxy(method, proto, host, url, content, headers)
    end

    turn_off_tracer
  end

  it 'should not resove if resolving is not enabled' do
    PositionResolver.stub(:position_enabled?).and_return false
    PositionResolver.should_not_receive :get_cache
    PositionResolver.get({})
  end

  it 'should handle malformed request' do
    request = {}
    position = PositionResolver.get(request)
    expected = {}

    position.should eq expected
  end

  it 'should use the cache to resolve' do
    PositionResolver.should_not_receive :get_google_geocoding
    request = {'gpsPosition' => {"latitude" => 45.4774536, "longitude" => 9.1906932}}
    response = {'address' => {'text' => "Via Fatebenesorelle, 2-14, 20121 Milan, Italy"}}
    PositionResolver.put_cache(request, response)

    position = PositionResolver.get(request)

    position.should eq response
  end

  it 'should not resolve local ip' do
    PositionResolver.should_not_receive :get_geoip

    private_ips = ['192.168.1.1', '10.1.2.3', '172.20.20.1', '169.254.34.75', '127.3.4.5']

    private_ips.each do |ip|
      request = {'ipAddress' => {'ipv4' => ip}}
      position = PositionResolver.get(request)
      expected = {}

      position.should eq expected
    end
  end

  it 'should not resolve malformed ip' do
    PositionResolver.should_not_receive :get_geoip

    request = {'ipAddress' => {'ipv4' => 'bogus'}}
    position = PositionResolver.get(request)
    expected = {}

    position.should eq expected
  end

  it 'should resolve geoip location' do
    request = {'ipAddress' => {'ipv4' => '93.62.139.46'}}
    position = PositionResolver.get(request)
    expected = {"latitude" => 45.4667, "longitude" => 9.2, "accuracy" => 20000, "address" => {"text"=>"Via Anselmo Ronchetti, 2-6, 20122 Milan, Italy"}}

    position.should eq expected
  end

  it 'should cache good results' do
    PositionResolver.should_receive :put_cache

    request = {'gpsPosition' => {"latitude" => 45.12345, "longitude" => 9.54321}}
    PositionResolver.get(request)
  end

  it 'should use google to resolve gps coords into address (geocoding)' do
    request = {'gpsPosition' => {"latitude" => 45.4774536, "longitude" => 9.1906932}}
    position = PositionResolver.get(request)
    expected = {"address"=>{"text"=>"Via Fatebenesorelle, 2-14, 20121 Milan, Italy"}}

    position.should eq expected
  end

  it 'should use google to resolve gsm cell into gps coords (geolocation)' do
    cells = [{mobileCountryCode: 222, mobileNetworkCode: 1, locationAreaCode: 61208, cellId: 528, signalStrength: -92, timingAdvance: 0, age: 0}]
    request = {'cellTowers' => cells, radioType: 'gsm'}

    position = PositionResolver.get(request)

    lat = position['latitude']
    lon = position['longitude']
    accuracy = position['accuracy']

    lat.should be_within(0.00005).of(45.477492)
    lon.should be_within(0.00005).of(9.1907943)
    accuracy.should be_within(50).of(677)

    position['address'].should eq({"text"=>"Via Fatebenesorelle, 2-14, 20121 Milan, Italy"})
  end

  it 'should use google to resolve wifi into gps coords (geolocation)' do
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

    lat = position['latitude']
    lon = position['longitude']
    accuracy = position['accuracy']

    lat.should be_within(0.00005).of(45.4765431)
    lon.should be_within(0.00005).of(9.1907635)
    accuracy.should be_within(10).of(52)

    position['address']['text'].should include "Via della Moscova"
  end

end

end
end
