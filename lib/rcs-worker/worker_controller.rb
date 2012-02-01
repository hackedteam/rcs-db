
require 'json'
require_relative 'queue_manager'

# from RCS::Common
require 'rcs-common/trace'

module RCS
module Worker

class WorkerController
  extend RESTController
  include RCS::Tracer

  def get
    puts "GET"
    server_error("method not implemented")
  end
  
  def post
    
    return bad_request("no ids found.") if @params['ids'].nil?

    trace :debug, "PARAMS #{@params}"

    @params['ids'].each do |evidence|
      trace :debug, "QUEUE #{evidence}"
      QueueManager.instance.queue evidence['instance'], evidence['ident'], evidence['id']
    end
    ok('OK')
  end
  
  def delete
    puts "DELETE"
    server_error("method not implemented")
  end
  
  def put
    puts "PUT"
    server_error("method not implemented")
  end
  
end # RCS::Worker::WorkerController

end # RCS::Worker
end # RCS
