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

end

end #DB::
end #RCS::
