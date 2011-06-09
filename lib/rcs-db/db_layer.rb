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
      # use the credential stored by RCSDB
      if File.exist?('C:/RCSDB/etc/RCSDB.ini') then
        File.open('C:/RCSDB/etc/RCSDB.ini').each_line do |line|
          user = line.split('=')[1].chomp if line['user=']
          pass = line.split('=')[1].chomp if line['pass=']
          host = '127.0.0.1'
        end
      end
      @mysql = Mysql2::Client.new(:host => host, :username => user, :password => pass, :database => 'rcs')
      trace :info, "Connected to MySQL [#{user}:#{pass}]"
      @available = true
    rescue Exception => e
      trace :fatal, "Cannot connect to MySQL: #{e.message}"
      @available = false
      raise
    end
  end
  
  def mysql_query(query)
    begin
      @semaphore.synchronize do
        # try to reconnect if not connected
        mysql_connect('root', 'rootp123', Config.instance.global['DB_ADDRESS']) if not @available
        # execute the query
        @mysql.query(query, {:symbolize_keys => true})
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

end

end #DB::
end #RCS::
