#
# Layer for accessing the real DB
#

require_relative 'audit.rb'
require_relative 'config'

# from RCS::Common
require 'rcs-common/trace'

# system
require 'mysql2'
require 'mongo'
require 'mongoid'

# require all the DB objects
Dir[File.dirname(__FILE__) + '/db_objects/*.rb'].each do |file|
  require file
end

module RCS
module DB

class DB
  include Singleton
  include RCS::Tracer
  
  def initialize
    @available = false
    @semaphore = Mutex.new
  end
  
  def mysql_connect(user, pass, host)
    begin
      @mysql = Mysql2::Client.new(:host => host, :username => user, :password => pass, :database => 'rcs')
      trace :info, "Connected to MySQL [#{user}:#{pass}]"
      @available = true
    rescue Exception => e
      trace :fatal, "Cannot connect to MySQL: #{e.message}"
      @available = false
      raise
    end
  end
  
  def mysql_query(query, opts={:symbolize_keys => true})
    begin
      @semaphore.synchronize do
        # try to reconnect if not connected
        mysql_connect('root', 'rootp123', Config.instance.global['DB_ADDRESS']) if not @available
        # execute the query
        @mysql.query(query, opts)
      end
    rescue Mysql2::Error => e
      trace :error, "#{e.message}. Retrying ..."
      sleep 0.05
      retry
    rescue Exception => e
      trace :error, "MYSQL ERROR [#{e.sql_state}][#{e.error_number}]: #{e.message}"
      trace :error, "MYSQL QUERY: #{query}"
      @available = false if e.error_number == 2006
      raise
    end
  end
  
  def mysql_escape(*strings)
    strings.each do |s|
      s.replace @mysql.escape(s) if s.class == String
    end
  end
  
  # MONGO
  
  #TODO: index more classes...
  @@classes_to_be_indexed = [::Audit, ::User]
  
  def connect
    begin
      #TODO: username & password
      Mongoid.load!(Dir.pwd + '/config/mongoid.yaml')
      Mongoid.configure do |config|
        config.master = Mongo::Connection.new.db('rcs')
      end
      trace :info, "Connected to MongoDB"
    rescue Exception => e
      trace :fatal, e
      return false
    end
    return true
  end
  
  def create_indexes
    @@classes_to_be_indexed.each do |k|
      k.create_indexes
    end
  end

  def enable_sharding
    if Shard.count == 0
      output = Shard.create(Config.instance.global['CN'] + ':27018')
      trace :info, "Adding the first Shard: #{output}"
      raise "Cannot create shard" unless output['ok'] == 1
    end
    output = Shard.enable('rcs')
    trace :info, "Enable Sharding on 'rcs': #{output}"
  end

  def ensure_admin
    # check that at least one admin is present and enabled
    # if it does not exists, create it
    if User.count(conditions: {enabled: true, privs: 'ADMIN'}) == 0
      trace :warn, "No ADMIN found, creating a default admin user..."
      User.where(name: 'admin').delete_all
      user = User.create(name: 'admin') do |u|
        u[:pass] = u.create_password('adminp123')
        u[:enabled] = true
        u[:desc] = 'Default admin user'
        u[:privs] = ['ADMIN', 'SYS', 'TECH', 'VIEW']
        u[:locale] = 'en_US'
        u[:timezone] = 0
      end
      Audit.log :actor => '<system>', :action => 'user.create', :user => 'admin', :desc => "Created the default user 'admin'"

      group = Group.create(name: "administrators")
      group.users << user
      group.save
      Audit.log :actor => '<system>', :action => 'group.create', :group => 'administrators', :desc => "Created the default group 'administrators'"
    end
  end

  def ensure_signatures
    if Signature.count == 0
      trace :warn, "No Signature found, creating them..."
      Signature.create(scope: 'agent') { |s| s.value = SecureRandom.hex(16) }
      Signature.create(scope: 'collector') { |s| s.value = SecureRandom.hex(16) }
      Signature.create(scope: 'network') { |s| s.value = SecureRandom.hex(16) }
      Signature.create(scope: 'server') { |s| s.value = SecureRandom.hex(16) }
    end
  end

end

end #DB::
end #RCS::
