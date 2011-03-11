#
# The Audit class, everything happening on the system should be logged
#

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
    trace :debug, params
  end

end

end #DB::
end #RCS::
