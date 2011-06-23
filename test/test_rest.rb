require_relative 'helper'
require 'uuidtools'
require 'bson'

require_db 'rest'

# for cookie tests
SESSION_ID = "eb92cf60-4f26-4cbb-b5db-5a8e5682e86a"

class DummyController < RCS::DB::RESTController
  def trace(a,b)
  end
end

class RESTGeneric < Test::Unit::TestCase
  def setup
    @controller = DummyController.new
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
end

class RESTInvalidSession < Test::Unit::TestCase
  def setup
    sm = MiniTest::Mock.new
    sm.expect :get, nil, [SESSION_ID]
    sm.expect :update, nil, [SESSION_ID]
    
    RCS::DB::RESTController.instance_eval { @session_manager = sm }
    
    @controller = DummyController.new
  end
  
  def test_invalid_session
    def @controller.get_rule() assert_true 1 end
    @controller.request = {method: 'GET', uri_params: ['get_rule'], cookie: SESSION_ID}
    response = @controller.act!
    
    assert_not_nil response
    assert_equal 403, response.status
    assert_equal 'INVALID_COOKIE', response.content
  end
end

class RESTValidSession < Test::Unit::TestCase
  def setup
    sm = MiniTest::Mock.new
    sm.expect :get, Object.new, [SESSION_ID]
    sm.expect :update, nil, [SESSION_ID]
    
    RCS::DB::RESTController.instance_eval { @session_manager = sm }
    @controller = DummyController.new
  end
  
  def test_invalid_action
    @controller.request = {:uri_params => [], cookie: SESSION_ID}

    response = @controller.act!
    
    assert_not_nil response
    assert_equal 500, response.status
    assert_equal 'NULL_ACTION', response.content
  end

  def test_exception_in_controller
    def @controller.index() raise "This should be trapped" end
    @controller.request = {method: 'GET', uri_params: [], cookie: SESSION_ID}

    response = @controller.act!

    assert_not_nil response
    assert_equal 500, response.status
    assert_equal 'SERVER_ERROR', response.content
  end

  def test_method_called_with_nil_response
    def @controller.index() return nil end
     @controller.request = {method: 'GET', uri_params: [], cookie: SESSION_ID}
    
    response = @controller.act!
    
    assert_not_nil response
    assert_equal 500, response.status
    assert_equal 'CONTROLLER_ERROR', response.content
  end

  def test_method_called_with_insufficient_level
    def @controller.index() raise RCS::DB::NotAuthorized.new(:admin, []) end
    @controller.request = {method: 'GET', uri_params: [], cookie: SESSION_ID}
    
    response = @controller.act!
    
    assert_not_nil response
    assert_equal 403, response.status
  end

  # GET /master/123
  def test_GET_with_id
    def @controller.show() "show called #{@params['_id']}!" end
    @controller.request = {method: 'GET', uri_params: ['123']}
    
    result = @controller.act!
    assert_equal "show called 123!", result
  end
  
  # GET /master/get_rule/123
  def test_GET_with_method_and_id
    def @controller.get_rule() "get_rule #{@params['_id']} called!" end
    @controller.request = {method: 'GET', uri_params: ['get_rule', '123']}
    
    result = @controller.act!
    assert_equal "get_rule 123 called!", result
  end

  # GET /master/get_rule/123?q=pippo
  def test_GET_with_method_and_id_and_CGI_query
    def @controller.get_rule() "get_rule #{@params['_id']} #{@params['q']} called!" end
    @controller.request = {method: 'GET', uri_params: ['get_rule', '123'], params: {'q' => 'pippo'}}

    result = @controller.act!
    assert_equal "get_rule 123 pippo called!", result
  end

  # POST /master/get_rule/123 json {"q": "pippo"}
  def test_POST_with_method_and_id_and_json_body
    def @controller.get_rule() "get_rule #{@params['_id']} #{@params['q']} called!" end
    @controller.request = {method: 'GET', uri_params: ['get_rule', '123'], params: {'q' => 'pippo'}}

    result = @controller.act!
    assert_equal "get_rule 123 pippo called!", result
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

end
