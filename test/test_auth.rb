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

  def test_get_login_info
    @rest.http_parse(@http_headers, 'GET', '/auth/login', nil, nil)
  end

  def test_login
    @rest.http_parse(@http_headers, 'POST', '/auth/login', nil, 'user=testuser&pass=testpwd')
  end

  def test_logout
    @rest.http_parse(@http_headers, 'POST', '/auth/logout', nil, nil)
  end

  def test_fake
    @rest.http_parse(@http_headers, 'GET', '/auth/fake', nil, nil)
  end
end

