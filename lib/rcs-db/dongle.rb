# encoding: utf-8
#
#  Hardware dongle handling stuff
#

# from RCS::Common
require 'rcs-common/trace'

require_relative 'frontend'

module RCS
module DB

class NoDongleFound < StandardError
  def initialize
    super "NO dongle found, cannot continue"
  end
end

class Dongle
  include RCS::Tracer

  DONT_STEAL_RCS = "∆©ƒø†£¢∂øª˚¶∞¨˚˚˙†´ßµ∫√Ïﬁˆ¨Øˆ·‰ﬁÎ¨"

  @@serial = '1234567890'
  @@count = 0

  class << self

    def info
      info = {}

      info[:serial] = @@serial
      info[:time] = Time.now.getutc
      info[:oneshot] = @@count

      return info
    end

    def decrement
      @@count -= 1
    end

    def time
      return Time.now.getutc

      begin
        Timeout::timeout(3) do
          # fallback to http request
          http = Net::HTTP.new('developer.yahooapis.com', 80)
          resp = http.request_get('/TimeService/V1/getTime?appid=YahooDemo')
          resp.kind_of? Net::HTTPSuccess or raise
          parsed = XmlSimple.xml_in(resp.body)
          return parsed['Timestamp'].first.to_i
        end
      rescue Exception => e
        return Time.now.getutc.to_i
      end
    end

  end

end

end #DB::
end #RCS::
