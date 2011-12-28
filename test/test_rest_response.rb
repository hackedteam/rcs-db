require 'helper'
require_db 'rest_response'

class TestRESTResponse < Test::Unit::TestCase

def test_response_base_initialization
  response = RCS::DB::RESTResponse.new 200, 'test'
  assert_equal 200, response.status
  assert_equal 'test', response.content
  assert_equal 'application/json', response.content_type
  assert_nil response.cookie
end

def test_response_initialization_with_content_type
  response = RCS::DB::RESTResponse.new 200, 'test', {content_type: 'binary/octet-stream'}
  assert_equal 200, response.status
  assert_equal 'test', response.content
  assert_equal 'binary/octet-stream', response.content_type
  assert_nil response.cookie
end

def test_response_initialization_with_cookie
  response = RCS::DB::RESTResponse.new 200, 'test', {cookie: 'this is a cookie!'}
  assert_equal 200, response.status
  assert_equal 'test', response.content
  assert_equal 'application/json', response.content_type
  assert_equal 'this is a cookie!', response.cookie
end

def test_response_initialization_with_content_type_and_cookie
  opts = {content_type: 'binary/octet-stream', cookie: 'this is a cookie!'}
  response = RCS::DB::RESTResponse.new 200, 'test', opts
  assert_equal 200, response.status
  assert_equal 'test', response.content
  assert_equal 'binary/octet-stream', response.content_type
  assert_equal 'this is a cookie!', response.cookie
end

class DummyConnection
  attr_reader :http_headers
  def initialize
    @http_headers = "Pippo\x00Pluto\x00"
  end
end

class KeepAliveConnection
  attr_reader :http_headers
  def initialize
    @http_headers = "Connection: keep-alive\x00Pluto"
  end
end

def test_prepare_base_response
  content = {action: 'test'}
  response = RCS::DB::RESTResponse.new 200, content
  reply = response.prepare_response DummyConnection.new
  assert_equal 200, reply.status
  assert_not_nil reply.status_string
  assert_equal 'application/json', reply.headers['Content-Type']
  assert_nil reply.headers['Set-Cookie']
  assert_equal 'close', reply.headers['Connection']
  assert_equal content.to_json, reply.content
end

def test_prepare_response_keepalive
  response = RCS::DB::RESTResponse.new 200, 'test'
  reply = response.prepare_response KeepAliveConnection.new
  assert_true reply.keep_connection_open
  assert_equal 'keep-alive', reply.headers['Connection']
end

def test_prepare_response_with_cookie
  response = RCS::DB::RESTResponse.new 200, 'test', {cookie: 'this is a cookie!'}
  reply = response.prepare_response DummyConnection.new
  assert_equal 'this is a cookie!', reply.headers['Set-Cookie']
end

def test_prepare_response_with_content_type
  response = RCS::DB::RESTResponse.new 200, 'test', {content_type: 'binary/octet-stream'}
  reply = response.prepare_response DummyConnection.new
  assert_equal 'binary/octet-stream', reply.headers['Content-Type']
end

end # TestRESTResponse