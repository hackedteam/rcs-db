require 'helper'

require 'json'

module RCS

class EvidenceManager
  def trace(a,b)
    puts b
  end
end

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
    puts b
  end
end

class ParserTest < Test::Unit::TestCase

  def setup
    # create a fake authenticated user and session
    @cookie = SessionManager.instance.create(1, 'test-user', :server)
    @controller = EvidenceController.new
    @rest = Classy.new
    @http_headers = nil
    @instance = 'test-instance'
  end

  def test_create_not_enough_privileges
    @controller.init(nil, 'PUT', '/evidence', @cookie, 'test-evidence-content')

    # set the wrong level (other then :server)
    sess = @controller.instance_variable_get(:@session)
    sess[:level] = :admin

    # this should fail, we don't have enough privileges
    assert_raise(RCS::DB::NotAuthorized) do
      @controller.create
    end
  end

  def test_start
    content = {:bid => 1,
               :build => 'RCS_0000test',
               :instance => @instance,
               :subtype => 'test-subtype',
               :version => 2011030401,
               :user => 'test-user',
               :device => 'test-device',
               :source => 'test-source'
              }
    status, *dummy = @rest.http_parse(@http_headers, 'POST', '/evidence/start', @cookie, content.to_json)
    assert_equal 200, status
  end

  def test_create
    binary = SecureRandom.random_bytes(1024)
    status, content, *dummy = @rest.http_parse(@http_headers, 'POST', "/evidence/#{@instance}", @cookie, binary)
    assert_equal 200, status
    assert_equal binary.size, JSON.parse(content)['bytes']
  end

  def test_stop
    content = {:bid => 1, :instance => @instance}
    status, *dummy = @rest.http_parse(@http_headers, 'POST', '/evidence/stop', @cookie, content.to_json)
    assert_equal 200, status
  end

  def test_timeout
    content = {:bid => 1, :instance => @instance}
    status, *dummy = @rest.http_parse(@http_headers, 'POST', '/evidence/timeout', @cookie, content.to_json)
    assert_equal 200, status
  end

end

end #DB::
end #RCS::