require 'helper'

=begin

require_db 'parser'
require_db 'auth'

module RCS
module DB
class AuthController
  def trace(a,b)
  end
end

class Config
  def trace(a, b)
  end
end

class Audit
  def self.trace(a, b)
  end
end

# fake class to hold the Mixin
class Classy
  include RCS::DB::Parser
  # fake trace method for testing
  def trace(a, b)
  end
end

class DB
  def trace(a, b)
  end
end

class ParserTest < Test::Unit::TestCase
  
  def setup
    @parser = Classy.new
    @http_headers = nil
  end
  
  def test_login
    Config.instance.load_from_file
    account = {:user => "test-user", :pass => 'test-pass'}
    
    status, content, content_type, cookie = @parser.process_request(@http_headers, 'POST', '/auth/login', nil, account.to_json, nil)
    assert_equal 200, status
    assert_false cookie.nil?
    
    status, content, content_type = @parser.process_request(@http_headers, 'GET', '/auth/login', cookie, nil, nil)
    assert_equal 200, status
    assert_false content.nil?
    
    response = JSON.parse(content)
    assert_equal cookie, response['cookie']
    assert_equal account[:user], response['user']
    #assert_equal 'admin', response['level']
  end
  
  def test_login_server
    Config.instance.load_from_file
    account = {:user => "test-server", :pass => File.read(Config.instance.file('SERVER_SIG')).chomp}
    status, content, content_type, cookie = @parser.process_request(@http_headers, 'POST', '/auth/login', nil, account.to_json, nil)
    assert_equal 200, status
    assert_false cookie.nil?
    status, content, content_type = @parser.process_request(@http_headers, 'GET', '/auth/login', cookie, nil, nil)
    assert_equal 200, status
    assert_false content.nil?

    response = JSON.parse(content)
    assert_equal account[:user], response['user']['name']
    assert_equal ['server'], response['level']
  end

  def test_logout_no_cookie
    status, content, content_type, cookie = @parser.process_request(@http_headers, 'POST', '/auth/logout', nil, nil, nil)
    assert_equal 403, status
    assert_true cookie.nil?
  end

  def test_logout_after_login
    Config.instance.load_from_file
    account = {:user => "test-user", :pass => 'test-pass'}
    status, content, content_type, cookie = @parser.process_request(@http_headers, 'POST', '/auth/login', nil, account.to_json, nil)
    assert_equal 200, status
    assert_false cookie.nil?
    status, content, content_type, cookie = @parser.process_request(@http_headers, 'POST', '/auth/logout', cookie, nil, nil)
    assert_equal 200, status
    assert_true cookie.nil?
  end

  def test_fake
    status, content, content_type, cookie = @parser.process_request(@http_headers, 'GET', '/auth/fake', nil, nil, nil)
    assert_equal 403, status
    assert_true cookie.nil?
  end

  def test_no_double_login
    Config.instance.load_from_file
    account = {:user => "test-user", :pass => 'test-pass'}
    status, content, content_type, cookie = @parser.process_request(@http_headers, 'POST', '/auth/login', nil, account.to_json, nil)
    assert_equal 200, status
    assert_false cookie.nil?

    # login again
    # the previous session should be destroyed and be invalidated
    status, content, content_type, cookie_new = @parser.process_request(@http_headers, 'POST', '/auth/login', nil, account.to_json, nil)
    assert_equal 200, status
    assert_false cookie_new.nil?

    # this must fail since the old session is not valid anymore
    status, content, content_type = @parser.process_request(@http_headers, 'GET', '/auth/login', cookie, nil, nil)
    assert_equal 403, status
    assert_true content.nil?

    # this is the new session and must be valid
    status, content, content_type = @parser.process_request(@http_headers, 'GET', '/auth/login', cookie_new, nil, nil)
    assert_equal 200, status
    assert_false content.nil?
  end

  def test_double_login_for_server
    Config.instance.load_from_file
    account = {:user => "test-server", :pass => File.read(Config.instance.file('SERVER_SIG')).chomp}
    status, content, content_type, cookie = @parser.process_request(@http_headers, 'POST', '/auth/login', nil, account.to_json, nil)
    assert_equal 200, status
    assert_false cookie.nil?

    # login again
    # the previous session should be destroyed and be invalidated
    status, content, content_type, cookie_new = @parser.process_request(@http_headers, 'POST', '/auth/login', nil, account.to_json, nil)
    assert_equal 200, status
    assert_false cookie_new.nil?

    # this must fail since the old session is not valid anymore
    status, content, content_type = @parser.process_request(@http_headers, 'GET', '/auth/login', cookie, nil, nil)
    assert_equal 200, status
    assert_false content.nil?

    # this is the new session and must be valid
    status, content, content_type = @parser.process_request(@http_headers, 'GET', '/auth/login', cookie_new, nil, nil)
    assert_equal 200, status
    assert_false content.nil?
  end

end

end #DB::
end #RCS::

=end