require 'helper'

require 'json'

module RCS

class EvidenceManager
  def trace(a,b)
  end
  def store_evidence(sess, s, c)
    # do nothing during test
  end
end

module DB

class EvidenceController
  def trace(a,b)
  end
end

class DB
  def mysql_connect; end
  def mysql_query(q); end
  def backdoor_evidence_key(id)
    return 'evidence-key'
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
    @session = SessionManager.instance.create({:name => 'test-server'}, [:server], '127.0.0.1')
    @cookie = "session=#{@session[:cookie]}"
    @controller = EvidenceController.new
    @rest = Classy.new
    @http_headers = nil
    @instance = 'test-instance'
  end

  def teardown
    SessionManager.instance.delete(@session)
  end

  def test_create_not_enough_privileges
    @controller.init(nil, 'PUT', '/evidence', @cookie, 'test-evidence-content', '127.0.0.1')
    
    # set the wrong level (other then :server)
    sess = @controller.instance_variable_get(:@session)
    sess[:level] = [:admin]

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
               :source => 'test-source',
               :sync_time => Time.now.to_i
              }
    status, *dummy = @rest.http_parse(@http_headers, 'POST', '/evidence/start', @cookie, content.to_json, nil)
    assert_equal 200, status
  end

  def test_create
    binary = SecureRandom.random_bytes(1024)
    status, content, *dummy = @rest.http_parse(@http_headers, 'POST', "/evidence/#{@instance}", @cookie, binary, nil)
    assert_equal 200, status
    assert_equal binary.size, JSON.parse(content)['bytes']
  end

  def test_stop
    content = {:bid => 1, :instance => @instance}
    status, *dummy = @rest.http_parse(@http_headers, 'POST', '/evidence/stop', @cookie, content.to_json, nil)
    assert_equal 200, status
  end

  def test_timeout
    content = {:bid => 1, :instance => @instance}
    status, *dummy = @rest.http_parse(@http_headers, 'POST', '/evidence/timeout', @cookie, content.to_json, nil)
    assert_equal 200, status
  end

end

end #DB::
end #RCS::