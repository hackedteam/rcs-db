
module RCS
module Worker

class WorkerController < RESTController

  def get
    puts "GET"
    ok
  end

  def post
    puts "POST"
    ok
  end

  def delete
    puts "DELETE"
    ok
  end

  def put
    puts "PUT"
    ok
  end

end # RCS::Worker::WorkerController

end # RCS::Worker
end # RCS