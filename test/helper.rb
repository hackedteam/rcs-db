require 'rubygems'

require 'json'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

require 'test/unit'
require 'minitest/mock'

#$LOAD_PATH.unshift(File.dirname(__FILE__))
#$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
#require 'rcs-db'
#require 'rcs-worker'

def prepare_request(method, uri, cookie, content, query, peer)
  request = {
          method: method,
          uri: uri,
          cookie: cookie,
          content: content,
          query: query,
          peer: peer
      }
end