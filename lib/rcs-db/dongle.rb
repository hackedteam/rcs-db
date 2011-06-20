#
#  Hardware dongle handling stuff
#

# from RCS::Common
require 'rcs-common/trace'


module RCS
module DB

class NoDongleFound < StandardError
  def initialize
    super "NO dongle found, cannot continue"
  end
end

class Dongle
  include RCS::Tracer

  @@serial = '1234567890'
  @@count = 5

  class << self

    def serial
      #raise NoDongleFound
      return @@serial
    end

    def count
      return @@count
    end

    def decrement
      @@count -= 1
    end

    def time
      Time.now.getutc
    end

  end

end

end #DB::
end #RCS::
