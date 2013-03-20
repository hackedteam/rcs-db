#
# Injector upgrade
#

# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

class BuildInjector < Build

  def initialize
    super
    @platform = 'injector'
  end

  def unique(core)
    # nothing to do here...
  end

end

end #DB::
end #RCS::
