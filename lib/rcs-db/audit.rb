#
# The Audit class, everything happening on the system should be logged
#

require 'rcs-common/trace'

module RCS
module DB

class Audit
  extend RCS::Tracer

  # expected parameters:
  #  :actor
  #  :action
  #  :user
  #  :group
  #  :activity
  #  :target
  #  :backdoor
  #  :desc
  def self.log(params)
    #TODO: implement audit 
    trace :debug, params
  end

end

end #DB::
end #RCS::
