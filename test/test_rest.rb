require 'helper'
require 'uuidtools'
require 'bson'

require_db 'rest'

class DummyController < RCS::DB::RESTController
  def trace(a,b)
  end
end

class RESTTest < Test::Unit::TestCase
  
  def setup
    @controller = DummyController.new
  end
  
  def teardown
    # Do nothing
  end
  
  def test_get_valid_controller
    request = {controller: 'DummyController', method: 'GET', uri_params: []}
    controller = RCS::DB::RESTController.get request
    assert_not_nil controller
  end
  
  def test_get_invalid_controller
    request = {controller: 'InvalidController', method: 'GET', uri_params: []}
    controller = RCS::DB::RESTController.get request
    assert_nil controller
  end
  
  def test_GET_to_index_action
    assert_equal :index, @controller.map_method_to_action('GET', [].empty?)
  end

  def test_GET_to_show_action
    assert_equal :show, @controller.map_method_to_action('GET', ["param"].empty?)
  end

  def test_POST_to_create_action
    assert_equal :create, @controller.map_method_to_action('POST', [].empty?)
  end

  def test_PUT_to_update_action
    assert_equal :update, @controller.map_method_to_action('PUT', [].empty?)
  end

  def test_DELETE_to_destroy_action
    assert_equal :destroy, @controller.map_method_to_action('DELETE', [].empty?)
  end
  
  # GET /master/123
  def test_GET_with_id
    def @controller.show() "show called!" end
    @controller.request = {method: 'GET', uri_params: ['123']}
    
    result = @controller.act!(nil)
    assert_equal "show called!", result
  end
  
  # GET /master/get_rule/123
  def test_GET_with_method_and_id
    def @controller.get_rule() "get_rule #{@params['_id']} called!" end
    @controller.request = {method: 'GET', uri_params: ['get_rule', '123']}
    
    result = @controller.act!(nil)
    assert_equal "get_rule 123 called!", result
  end
  
  # GET /master/get_rule/123?q=pippo
  def test_GET_with_method_and_id_and_CGI_query
    def @controller.get_rule() "get_rule #{@params['_id']} #{@params['q']} called!" end
    @controller.request = {method: 'GET', uri_params: ['get_rule', '123'], params: {'q' => 'pippo'}}
    
    result = @controller.act!(nil)
    assert_equal "get_rule 123 pippo called!", result
  end
  
  # POST /master/get_rule/123 json {"q": "pippo"}
  def test_POST_with_method_and_id_and_json_body
    def @controller.get_rule() "get_rule #{@params['_id']} #{@params['q']} called!" end
    @controller.request = {method: 'GET', uri_params: ['get_rule', '123'], params: {'q' => 'pippo'}}

    result = @controller.act!(nil)
    assert_equal "get_rule 123 pippo called!", result
  end
  
  def test_act_calling_proper_action
    # make controller respond to requested action
    def @controller.hello() "Hello!" end
    
    @controller.request = {:uri_params => [:hello]}
    result = @controller.act!(nil)
    assert_equal "Hello!", result
  end
  
  def test_act_calling_without_action
    @controller.request = {:uri_params => []}
    result = @controller.act!(nil)
    assert_equal RCS::DB::RESTResponse, result.class
    assert_equal 500, result.status
    assert_equal 'NULL_ACTION', result.content
  end
  
  def test_act_calling_with_invalid_action
    @controller.request = {:uri_params => [:invalid]}
    result = @controller.act!(nil)
    assert_equal RCS::DB::RESTResponse, result.class
    assert_equal 500, result.status
    assert_equal 'NULL_ACTION', result.content
  end
  
  def test_mongoid_query_invalid_bson
    result = @controller.mongoid_query { raise BSON::InvalidObjectId.new }
    assert_equal RCS::DB::RESTResponse, result.class
    assert_equal 400, result.status # BAD REQUEST
  end

  def test_mongoid_query_generic_exception
    result = @controller.mongoid_query { raise "OUCH!" }
    assert_equal RCS::DB::RESTResponse, result.class
    assert_equal 404, result.status # NOT FOUND
  end

  def test_response_not_found
    result = RCS::DB::RESTController.not_found
    assert_equal RCS::DB::RESTResponse, result.class
    assert_equal 404, result.status # NOT FOUND
  end

  def test_response_not_authorized
    message = "Permission denied!"
    result = RCS::DB::RESTController.not_authorized message
    assert_equal RCS::DB::RESTResponse, result.class
    assert_equal 403, result.status # NOT FOUND
    assert_equal message, result.content
  end

  def test_response_conflict
    message = "I'll fight for that!"
    result = RCS::DB::RESTController.conflict message
    assert_equal RCS::DB::RESTResponse, result.class
    assert_equal 409, result.status # NOT FOUND
    assert_equal message, result.content
  end
  
  def test_response_bad_request
    message = "What?!?"
    result = RCS::DB::RESTController.bad_request message
    assert_equal RCS::DB::RESTResponse, result.class
    assert_equal 400, result.status # NOT FOUND
    assert_equal message, result.content
  end

  def test_response_server_error
    message = "Core meltdown!"
    result = RCS::DB::RESTController.server_error message
    assert_equal RCS::DB::RESTResponse, result.class
    assert_equal 500, result.status # NOT FOUND
    assert_equal message, result.content
  end
end
