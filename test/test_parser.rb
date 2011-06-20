require 'helper'
require_relative '../lib/rcs-db/parser.rb'

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
    assert_true params[:_default].empty?
  end
  
  def test_parse_uri_with_action_override
    controller, params = @parser.parse_uri('/fake/destroy')
    assert_equal "FakeController", controller
    assert_equal "destroy", params[:_default].first
  end
  
  def test_parse_uri_with_action_override_and_params
    controller, params = @parser.parse_uri('/fake/destroy/1234')
    assert_equal "FakeController", controller
    assert_equal "destroy", params[:_default].first
    assert_equal "1234", params[:_default].second
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

  def test_guid_from_invalid_cookie
    session_id = @parser.guid_from_cookie("session=1234567890")
    assert_nil session_id
  end

  def test_guid_from_valid_cookie
    session_id_from_cookie = @parser.guid_from_cookie("session=#{SESSION_ID}")
    assert_equal SESSION_ID, session_id_from_cookie
  end
  
  def test_request_index_page
    request = @parser.prepare_request('GET', '/index', nil, nil, nil)
    
    # not existing pages should receive 404 status code
    assert_equal 'IndexController', request[:controller]
    assert_nil request[:cookie]
    assert_empty request[:params][:_default]
  end
  
  def test_request_show_page
    request = @parser.prepare_request('GET', '/show/1234', nil, nil, nil)
    
    # not existing pages should receive 404 status code
    assert_equal 'ShowController', request[:controller]
    assert_nil request[:cookie]
    assert_equal "1234", request[:params][:_default].first
  end
  
  def test_request_flex_overridden_method_page
    content = {'user' => 'test'}
    request = @parser.prepare_request('GET', '/fake/destroy', nil, "session=#{SESSION_ID}", content.to_json)
    
    # not existing pages should receive 404 status code
    assert_equal 'FakeController', request[:controller]
    assert_equal SESSION_ID, request[:cookie]
    assert_equal "destroy", request[:params][:_default].first
    assert_equal "test", request[:params]['user']
  end

  def test_flex_overriden_action
    controller = MiniTest::Mock.new
    controller.expect :destroy, nil, nil
    
    request = {method: 'DELETE', params: {_default: ['destroy']}}
    action = @parser.flex_override_action controller, request
    assert_equal :destroy, action
    assert_empty request[:params][:_default]
  end

  def test_flex_direct_action
    controller = MiniTest::Mock.new
    
    request = {method: 'GET', params: {_default: ['123']}}
    action = @parser.flex_override_action controller, request
    assert_equal :show, action
    assert_equal "123", request[:params][:_default].first
  end
end

