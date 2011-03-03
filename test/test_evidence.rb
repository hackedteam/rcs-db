require 'helper'

module RCS
module DB

class EvidenceController
  def trace(a,b)
    puts b
  end
end

# fake class to hold the Mixin
class Classy
  include RCS::DB::Parser
  # fake trace method for testing
  def trace(a, b)
  end
end

class ParserTest < Test::Unit::TestCase

  def setup
    # create a fake authenticated user and session
    @cookie = SessionManager.instance.create(1, 'test-user', :admin)
    @controller = EvidenceController.new
    @rest = Classy.new
    @http_headers = nil
  end

  def test_create_not_enough_privileges
    @controller.init(nil, 'PUT', '/evidence', @cookie, 'test-evidence-content')

    # this should fail, we don't have enough privileges
    assert_raise(RCS::DB::NotAuthorized) do
      @controller.create
    end
  end

  def test_create_not_privileges_rest
    status, *dummy = @rest.http_parse(@http_headers, 'POST', '/evidence', @cookie, 'test-evidence-content')
    assert_equal 403, status
  end

  def test_create_enough_privileges
    evidence_content = 'test-evidence-content'
    @controller.init(nil, 'PUT', '/evidence', @cookie, evidence_content)

    # set the correct privs (we need to be server)
    sess = @controller.instance_variable_get(:@session)
    sess[:level] = :server

    status, content, type = @controller.create
    assert_equal 200, status
    assert_equal evidence_content.size, JSON.parse(content)['bytes']
  end


end

end #DB::
end #RCS::