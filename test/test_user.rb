require 'helper'

module RCS
module DB
class UserController
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

  def test_user_index
    @rest.http_parse(@http_headers, 'GET', '/user', nil, nil)
  end

  def test_user_show
    @rest.http_parse(@http_headers, 'GET', '/user/id', nil, nil)
  end

end

