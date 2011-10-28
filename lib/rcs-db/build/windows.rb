#
#  Agent creation superclass
#

require_relative '../build'

# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

class BuildWindows < Build

  def initialize
    super
    @platform = 'windows'
  end

  def patch(params)
    core = File.join @tmpdir, "core"

    trace :debug, "Build: patching: #{params}"

    file = File.open(core, 'rb+')
    content = file.read

    puts content['--demo--']
    puts content['MZ']
  end

  def scramble
    trace :debug, "#{self.class} #{__method__}"
  end

  def melt
    trace :debug, "#{self.class} #{__method__}"
  end

end

end #DB::
end #RCS::
