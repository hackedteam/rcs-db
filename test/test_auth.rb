require 'helper'

module RCS
module DB
class AuthController
  def trace(a,b)
    puts b
  end
end
end
end

# fake class to hold the Mixin
class Classy
  include RCS::DB::Parser
  # fake trace method for testing
  def trace(a, b)
    puts b
  end
end

class ParserTest < Test::Unit::TestCase

  def setup
    @rest = Classy.new
    @http_headers = nil
  end

  def test_login
    account = {:user => "test-user", :pass => 'test-pass'}
    status, content, content_type, cookie = @rest.http_parse(@http_headers, 'POST', '/auth/login', nil, account.to_json)
    assert_equal 200, status
    assert_false cookie.nil?
    status, content, content_type = @rest.http_parse(@http_headers, 'GET', '/auth/login', cookie, nil)
    assert_equal 200, status
    assert_false content.nil?

    response = JSON.parse(content)
    assert_equal cookie, response['cookie']
    assert_equal account[:user], response['user']
    assert_equal 'admin', response['level']
  end

  def test_logout_no_cookie
    status, content, content_type, cookie = @rest.http_parse(@http_headers, 'POST', '/auth/logout', nil, nil)
    assert_equal 403, status
    assert_true cookie.nil?
  end

  def test_logout_after_login
    account = {:user => "test-user", :pass => 'test-pass'}
    status, content, content_type, cookie = @rest.http_parse(@http_headers, 'POST', '/auth/login', nil, account.to_json)
    assert_equal 200, status
    assert_false cookie.nil?
    status, content, content_type, cookie = @rest.http_parse(@http_headers, 'POST', '/auth/logout', cookie, nil)
    assert_equal 200, status
    assert_true cookie.nil?
  end

  def test_fake
    status, content, content_type, cookie = @rest.http_parse(@http_headers, 'GET', '/auth/fake', nil, nil)
    assert_equal 403, status
    assert_true cookie.nil?
  end
end

