#
# The alerting subsystem
#

# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

class Alerting
  extend RCS::Tracer

  class << self

    def new_sync(agent)
      trace :debug, "ALERT: new sync"
      puts agent.inspect
    end

    def new_instance(agent)
      trace :debug, "ALERT: new instance"
    end

    def new_evidence(evidence)
      trace :debug, "ALERT: new evidence"
    end

  end
end

end # ::DB
end # ::RCS