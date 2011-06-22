require 'helper'
require_db 'parser'

# for cookie tests
SESSION_ID = "eb92cf60-4f26-4cbb-b5db-5a8e5682e86a"

# fake class to hold the Mixin
class DummyParser
  include RCS::DB::Parser
  # fake trace method for testing
  def trace(a, b)
  end
end

class ParserTest < Test::Unit::TestCase
  
  def setup
    @parser = DummyParser.new
    @http_headers = nil
  end
  
  def test_parse_uri_without_action_override
    controller, params = @parser.parse_uri('/fake')
    assert_equal "FakeController", controller
    assert_empty params
  end
  
  def test_parse_uri_with_action_override
    controller, params = @parser.parse_uri('/fake/destroy')
    assert_equal "FakeController", controller
    assert_equal "destroy", params.first
  end
  
  def test_parse_uri_with_action_override_and_params
    controller, params = @parser.parse_uri('/fake/destroy/1234')
    assert_equal "FakeController", controller
    assert_equal "destroy", params.first
    assert_equal "1234", params.second
  end
  
  def test_parse_nil_query_parameters
    assert_equal Hash.new, @parser.parse_query_parameters(nil)
  end
  
  def test_parse_valid_query_parameters
    result = @parser.parse_query_parameters("q=123")
    assert_equal , result['q'] = "123"
  end

  def test_parse_nil_json_content
    assert_equal Hash.new, @parser.parse_json_content(nil)
  end
  
  def test_parse_valid_json_content
    content = {'evil' => "Darth Vader"}
    result = @parser.parse_json_content(content.to_json)
    assert_equal "Darth Vader", result['evil']
  end

  def test_parse_invalid_json_content
    content = '{"evil" : "Darth Vader"' # missing } closing bracket
    result = @parser.parse_json_content(content.to_json)
    assert_nil result['evil']
  end

  def test_guid_from_invalid_cookie
    session_id = @parser.guid_from_cookie("session=1234567890")
    assert_nil session_id
  end

  def test_guid_from_valid_cookie
    session_id_from_cookie = @parser.guid_from_cookie("session=#{SESSION_ID}")
    assert_equal SESSION_ID, session_id_from_cookie
  end
  
  def test_request_GET_index_page
    request = @parser.prepare_request('GET', '/master', nil, nil, nil)
    
    assert_equal 'GET', request[:method]
    assert_equal 'MasterController', request[:controller]
    assert_nil request[:cookie]
    assert_empty request[:uri_params]
    assert_empty request[:params]
  end
  
  def test_request_GET_show_page
    request = @parser.prepare_request('GET', '/master/1234', nil, nil, nil)

    assert_equal 'GET', request[:method]
    assert_equal 'MasterController', request[:controller]
    assert_nil request[:cookie]
    assert_equal 1, request[:uri_params].size
    assert_equal "1234", request[:uri_params].first
    assert_empty request[:params]
  end
  
  def test_request_POST__with_id_param
    request = @parser.prepare_request('POST', '/master/destroy/123', nil, nil, nil)
    
    assert_equal 'POST', request[:method]
    assert_equal 'MasterController', request[:controller]
    assert_equal 2, request[:uri_params].size
    assert_equal "destroy", request[:uri_params].first
    assert_equal "123", request[:uri_params].second
  end

  def test_request_POST_with_json_content
    content = {'user' => 'test'}
    request = @parser.prepare_request('POST', '/master/update', nil, nil, content.to_json)

    assert_equal 'POST', request[:method]
    assert_equal 'MasterController', request[:controller]
    assert_equal 1, request[:uri_params].size
    assert_equal "update", request[:uri_params].first
    assert_equal 1, request[:params].size
    assert_equal "test", request[:params]['user']
  end

  def test_request_method_with_uri_query
    query = "q=pippo&params=123"
    request = @parser.prepare_request('GET', '/master/get', query, nil, nil)

    assert_equal 'GET', request[:method]
    assert_equal 'MasterController', request[:controller]
    assert_equal 1, request[:uri_params].size
    assert_equal 'get', request[:uri_params].first
    assert_equal 2, request[:params].size
    assert_equal 'pippo', request[:params]['q'].first
    assert_equal '123', request[:params]['params'].first
  end

  def test_request_with_cookie
    request = @parser.prepare_request('GET', '/master', nil, "session=#{SESSION_ID}", nil)
    assert_equal SESSION_ID, request[:cookie]
  end
end
