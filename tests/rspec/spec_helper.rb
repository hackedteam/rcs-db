require 'bundler'
require 'mongo'
require 'mongoid'
require 'pry'
require 'rcs-common/path_utils'
require 'fileutils'

# require customer rspec matchers
require File.expand_path 'spec_matchers', File.dirname(__FILE__)

# require factory framework
require File.expand_path 'spec_factories', File.dirname(__FILE__)

require_relative 'stubs/tracer'
require_relative 'stubs/mongoid'
require_relative 'stubs/archive_server'

# Define global before and each proc
RSpec.configure do |config|

  # * Clean up the spec_temp_folder
  # * Connecto to mongodb
  config.before(:all) do
    FileUtils.rm_rf(spec_temp_folder)
    FileUtils.mkdir_p(spec_temp_folder)
    mongo_setup
    empty_test_db
  end

  config.before(:each) do
    turn_off_tracer
    empty_test_db
  end

  config.after(:all) do
    FileUtils.rm_rf(spec_temp_folder)
  end
end

def spec_temp_folder(subpath = nil)
  @spec_temp_folder ||= File.join(File.dirname(__FILE__), '_temp')
  subpath && File.join(@spec_temp_folder, subpath) || @spec_temp_folder
end

def fixtures_path(subpath = nil)
  @fixtures_path ||= File.join(File.dirname(__FILE__), 'fixtures')
  subpath && File.join(@fixtures_path, subpath) || @fixtures_path
end

def rcs_require(relative_path, file)
  relative_path_file = File.join(Dir.pwd, relative_path, file)
  require_release(relative_path_file)
end

def require_db(file)
  rcs_require('lib/rcs-db/', file)
end

def require_aggregator(file)
  rcs_require('lib/rcs-aggregator/', file)
end

def require_intelligence(file)
  rcs_require('lib/rcs-intelligence/', file)
end

def require_worker(file)
  rcs_require('lib/rcs-worker/', file)
end

def require_connector(file)
  rcs_require('lib/rcs-connector/', file)
end

# Setup mongoid.
# Simulate a sharded enviroments
def mongo_setup
  Mongoid.load!('config/mongoid.yaml', :production)

  connection = Mongo::MongoClient.new(ENV['MONGOID_HOST'], ENV['MONGOID_PORT'])
  admin_db = connection.db('admin')
  shard_list = admin_db.command(listshards: 1)['shards']
  admin_db.command(addshard: "#{ENV['MONGOID_HOST']}:27018") if shard_list.empty?
  admin_db.command(enablesharding: ENV['MONGOID_DATABASE']) rescue nil
end

def empty_test_db
  Mongoid.purge!
end

# Check out RCS::Tracer module of rcs-common gem
def turn_off_tracer(opts = {})
  Log4r::Logger.stub(:[]).and_return(RCS::Stubs.logger(opts))
end

def turn_on_tracer
  Log4r::Logger.stub(:[]).and_return(nil)
end

# Stub the LicenseManager instance to simulate the presence of a valid license
def enable_license
  before do
    eval 'class LicenseManager; end' unless defined? LicenseManager
    LicenseManager.stub(:instance).and_return mock()
    LicenseManager.instance.stub(:check).and_return true
  end
end

# Stub all the methods that send alerts or push notification to the console
def silence_alerts
  before do
    Entity.any_instance.stub :alert_new_entity
    Entity.any_instance.stub :push_notify
    RCS::DB::LinkManager.any_instance.stub :alert_new_link
  end
end

# Restore a file created with mongodump
# Assumes that the dump file is located in the fixture folder (tests/rspec/fixtures)
def mongorestore(path)
  path = File.expand_path File.join(fixtures_path, path)
  return unless File.exists? path
  empty_test_db
  cmd = "mongorestore \"#{path}\""
  puts cmd
  `#{cmd}`
end

# Change the default temporary folder
# and clean it after each example
def stub_temp_folder
  before do
    RCS::DB::Config.instance.stub(:temp_folder_name).and_return spec_temp_folder
    FileUtils.mkdir_p RCS::DB::Config.instance.temp
  end

  after { FileUtils.rm_r RCS::DB::Config.instance.temp }
end
