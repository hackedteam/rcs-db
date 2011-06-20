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

  def test_user_index
    @parser.process_request(@http_headers, 'GET', '/user', nil, nil, nil)
  end

  def test_user_show
    @parser.process_request(@http_headers, 'GET', '/user/id', nil, nil, nil)
  end

end

