
require 'json'

module RCS
module Worker

class WorkerController < RESTController
  
  def get
    puts "GET"
    server_error("method not implemented")
  end
  
  def post
    
    return bad_request("no ids found.") if @params['ids'].nil?
    
    @params['ids'].each do |id|
      trace :info, "processing evidence #{id}"
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
