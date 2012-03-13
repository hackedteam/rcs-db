require 'helper'
require_db 'events'

class EventsTest < Test::Unit::TestCase

  def setup
    @handler = new HTTPHandler
  end

=begin
  def test_process_http_request
    session_manager = MiniTest::Mock.new
    session_manager.expect :get,  Object.new
    session_manager.expect :update, nil

    rest_controller = MiniTest::Mock.new
    rest_controller.expect :get, Object.new
    rest_controller.expect :not_authorized, Object.new

    @handler.instance_eval { @session_manager = session_manager }
    @handler.instance_eval { @rest_controller = rest_controller }
  end
=end

end
