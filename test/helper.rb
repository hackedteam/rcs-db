require 'rubygems'
require 'simplecov'

SimpleCov.start if ENV['COVERAGE']

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

def require_db(file)
  relative_path_to_db = 'lib/rcs-db/'
  require_relative File.join(Dir.pwd, relative_path_to_db, file)
end

def require_worker(file)
  relative_path_to_worker = 'lib/rcs-worker/'
  require_relative File.join(Dir.pwd, relative_path_to_worker, file)
end
