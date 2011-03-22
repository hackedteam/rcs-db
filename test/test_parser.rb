require 'helper'

# fake class to hold the Mixin
class Classy
  include RCS::DB::Parser
  # fake trace method for testing
  def trace(a, b)
  end
end

class ParserTest < Test::Unit::TestCase

  def setup
    @rest = Classy.new
    @http_headers = nil
  end

  def test_get_fake_page
    status, content, content_type, cookie = @rest.http_parse(@http_headers, 'GET', '/fake/1', nil, nil)

    # not existing pages should receive 404 status code
    assert_equal 404, status
    assert_nil cookie
  end

  def test_get_fake_method
    status, content, content_type, cookie = @rest.http_parse(@http_headers, 'GET', '/auth/fake', nil, nil)

    # not existing pages should receive 403 status code
    assert_equal 403, status
    assert_nil cookie
  end

end

