# from RCS::Common
require 'rcs-common/trace'

class InstanceProcessor
  include RCS::Tracer

  SLEEP_TIME = 10
  
  def initialize(id)
    @id = id
    @evidences = []
    @state = :stopped
    @seconds_sleeping = 0
  end
  
  def resume
    @state = :running
    @seconds_sleeping = 0
    trace :debug, "[#{Thread.current}][#{@instance}] starting processing."
  end
  
  def take_some_rest
    sleep 1
    @seconds_sleeping += 1
    trace :debug, "[#{Thread.current}][#{@instance}] sleeping some [#{@seconds_sleeping}]."
  end
  
  def put_to_sleep
    @state = :stopped
    trace :debug, "[#{Thread.current}][#{@instance}] sleeping too much, let's stop!"
  end
  
  def stopped?
    @state == :stopped
  end
  
  def sleeping_too_much?
    @seconds_sleeping > SLEEP_TIME
  end
  
  def queue(evidence)
    @evidences << evidence unless evidence.nil?
    trace :info, "queueing #{evidence} for #{@id}"
    
    process = Proc.new do
      until sleeping_too_much?
        until @evidences.empty?
          resume
          ev = @evidences.shift
          trace :debug, "[#{Thread.current}][#{@instance}] processing #{ev}."
        end
        take_some_rest
      end
      
      put_to_sleep
    end
    
    if stopped?
      trace :debug, "deferring work for #{@instance}"
      EM.defer process
    end
  end
  
  def to_s
    "instance #{@id}: #{@evidences}"
  end
end