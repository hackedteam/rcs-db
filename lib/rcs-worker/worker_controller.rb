
require 'json'
require_relative 'queue_manager'
require_relative 'worker'

# from RCS::Common
require 'rcs-common/trace'

module RCS
module Worker

class WorkerController
  extend RESTController
  include RCS::Tracer

  def get
    Worker::resume_pending_evidences
    ok('Rescheduled evidences for processing.')
  end
  
  def post
    return bad_request("no ids found.") if @params['ids'].nil?

    @params['ids'].each do |evidence|
      QueueManager.instance.queue evidence['instance'], evidence['ident'], evidence['id']
    end
    ok('OK')
  end
  
  def delete
    server_error("method not implemented")
  end
  
  def put
    server_error("method not implemented")
  end
  
end # RCS::Worker::WorkerController

end # RCS::Worker
end # RCS
