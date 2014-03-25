require 'mongoid'
require 'rbconfig'
require 'socket'
require 'rcs-common/trace'
require 'rcs-common/fixnum'

require_relative 'audit'
require_relative 'config'

# require all the DB objects
Dir[File.dirname(__FILE__) + '/db_objects/*.rb'].each do |file|
  require file
end

require_relative 'cache'

module RCS
module DB

class DB
  include Singleton
  include RCS::Tracer

  def initialize
    @available = false
    @auth_required = false
  end

  def change_mongo_profiler_level
    result = session.command('$eval' => "db.getProfilingStatus()")
    profiler_level = result['retval']['was']

    trace(:warn, "MongoDB profiler is active") unless profiler_level.zero?

    new_level = RCS::DB::Config.instance.global['MONGO_PROFILER_LEVEL'] || 0
    new_level = 0 unless [0, 1, 2].include?(new_level)

    if new_level != profiler_level
      trace(:warn, "Changing mongoDB profiler level to #{new_level}")
      session.command('$eval' => "db.setProfilingLevel(#{new_level})")
    end
  rescue Exception => ex
    trace(:error, "Cannot enable mongoDB profiler: #{ex.message}")
  end

  def connect
    ENV['MONGOID_ENV'] = 'production'
    ENV['MONGOID_DATABASE'] = Config.instance.global['DB_NAME'] || 'rcs'
    ENV['MONGOID_HOST'] = Socket.gethostname
    ENV['MONGOID_PORT'] = "27017"

    Mongoid.load!(Config.instance.file('mongoid.yaml'), :production)

    trace :info, "Connected to MongoDB at #{ENV['MONGOID_HOST']}:#{ENV['MONGOID_PORT']}"
    trace :info, "mongodb version is #{mongo_version}"

    # change_mongo_profiler_level
    true
  rescue Exception => ex
    trace(:fatal, ex)
    false
  end

  def collection_stats(collection)
    session.command(collStats: collection_name(collection))
  end

  alias :collection_stat :collection_stats

  def sharded_collection?(collection)
    collection_stats(collection_name(collection))['sharded']
  end

  def collection_name(collection, ns: false)
    name = collection.respond_to?(:name) ? collection.name : collection
    ns ? "#{db_name}.#{name}" : name
  end

  def collection_names
    session.collections.map(&:name)
  end

  def drop_collection(collection_name)
    session[collection_name.to_s].drop
  end

  def db_stats
    session.command(dbStats: 1)
  end

  # TODO: find out if the parts where this method is used are
  # executed frequently, in that case, cache the new session
  def open(host, port, db, options = {})
    options[:max_retries] ||= 0
    new_session = Moped::Session.new(["#{host}:#{port}"], options)
    new_session.use(db)
    yield(new_session)
  rescue Moped::Errors::ConnectionFailure
    options[:raise]==false ? nil : raise
  ensure
    new_session.disconnect
  end

  def session(database = nil)
    default_session = Mongoid.default_session
    database ? default_session.with(database: database) : default_session
  end

  def mongo_version
    session.command(:buildinfo => 1)['version'] rescue "unknown"
  end

  def sharded_collections
    session('config')['collections']
  end

  def db_name
    session.instance_variable_get('@current_database').name
  end

  def collection_exists?(collection)
    collection_stats(collection)
    true
  rescue Moped::Errors::OperationFailure
    false
  end

  alias :collection_exist? :collection_exists?

  def indexes(collection)
    namespace = collection_name(collection, ns: true)
    session['system.indexes'].find(ns: namespace).map { |d| d['key'] }
  end

  def index_diff(mongoid_document_class)
    collection = mongoid_document_class.collection

    if !collection_exists?(collection)
      diff = {missing_collection: true}
      trace(:debug, "Index diff of #{mongoid_document_class.collection.name}: #{diff.inspect}")
      return diff
    end

    # Gets an array of hashes containing the index keys. Something
    # like [{"type"=>1}, {"type"=>1, "da"=>1, "aid"=>1}, {"da"=>1}].
    model_indexes_keys = mongoid_document_class.index_options.keys.map(&:stringify_keys)
    actual_indexes_keys = indexes(collection)

    # Exclude the automatic index on the "_id" attribute
    actual_indexes_keys.reject! { |hash| hash == {'_id' => 1} }

    # Exclude the automatic index on the shard key
    namespace = collection_name(collection, ns: true)
    coll = sharded_collections.find(_id: namespace).first
    model_shard_key = mongoid_document_class.shard_key_fields.inject({}) { |h, v| h[v.to_s] = 1; h }
    model_shard_key = nil if model_shard_key.empty?
    actual_shard_key = coll['key'] if coll

    diff = {}

    if !model_shard_key and !actual_shard_key
      # unsharded collection
    elsif model_shard_key and !actual_shard_key
      diff[:shard_key] = model_shard_key
    else #ignores any other case...
      if actual_shard_key and !model_shard_key
        trace :warn, "The shard key #{actual_shard_key.inspect} on #{namespace} has been removed from the model."
      end
      actual_indexes_keys.reject! { |hash| hash == actual_shard_key }
      actual_indexes_keys.reject! { |hash| hash == model_shard_key }
    end

    diff[:added] = model_indexes_keys - actual_indexes_keys
    diff[:removed] = actual_indexes_keys - model_indexes_keys
    diff[:added].map! do |index_key|
      opts = mongoid_document_class.index_options.find { |key, opts| key.stringify_keys == index_key }.last
      [index_key, opts.stringify_keys]
    end

    diff = nil if diff[:added].empty? and diff[:removed].empty? and !diff[:shard_key]
    trace :debug, "Index diff of #{namespace}: #{diff ? diff.inspect : 'none'}"
    diff
  end

  # This method may trigger:
  # - Creation of a new indexes
  # - Deletion of existing indexes
  # - Creation of a new shard key
  #
  # What is does not is:
  # - Delete/change an existing shard key
  def sync_indexes(mongoid_document_class)
    diff = index_diff(mongoid_document_class)
    return unless diff

    if diff[:missing_collection]
      trace :debug, "Creating collection and indexes of model #{mongoid_document_class.name}"
      if mongoid_document_class.respond_to?(:create_collection)
        mongoid_document_class.create_collection
      else
        mongoid_document_class.create_indexes
      end

      return
    end

    indexes = mongoid_document_class.collection.indexes
    coll_name = mongoid_document_class.collection.name

    if diff[:shard_key]
      trace :debug, "Enable sharding with key #{diff[:shard_key].inspect} on #{coll_name}"
      result = RCS::DB::Shard.set_key(mongoid_document_class.collection, diff[:shard_key])
      trace :debug, result
    end

    diff[:removed].each do |index_key|
      trace :debug, "Dropping index #{index_key.inspect} on #{coll_name}"
      indexes.drop(index_key)
    end

    diff[:added].each do |spec|
      index_key, opts = *spec
      trace :debug, "Creating index #{index_key.inspect} (#{opts.inspect}) on #{coll_name}"
      indexes.create(index_key, opts)
    end
  end

  # insert here the class to be indexed
  @@classes_to_be_indexed = [::Audit, ::User, ::Group, ::Alert, ::Status, ::Core, ::Collector,
                             ::Injector, ::Item, ::PublicDocument, ::EvidenceFilter, ::Entity,
                             ::WatchedItem, ::ConnectorQueue, ::Signature, ::Session, ::HandleBook]

  def create_indexes
    trace :info, "Database size is: " + db_stats['dataSize'].to_s_bytes
    trace :info, "Ensuring indexing on collections..."

    @@classes_to_be_indexed.each { |klass| sync_indexes(klass) }
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

  # check that at least one admin is present and enabled
  # if it does not exists, create it
  def ensure_admin
    return if User.where(enabled: true, privs: 'ADMIN').count > 0

    trace :warn, "No ADMIN found, creating a default admin user..."

    User.where(name: 'admin').delete_all

    if File.exist? Config.instance.file('admin_pass')
      admin_pass = File.read(Config.instance.file('admin_pass'))
      FileUtils.rm_rf Config.instance.file('admin_pass')
    else
      admin_pass = 'A1d2m3i4n5'
    end

    user = User.new

    user.name     = 'admin'
    user.pass     = admin_pass
    user.enabled  = true
    user.desc     = 'Default admin user'
    user.privs    = ::User::PRIVS
    user.locale   = 'en_US'
    user.timezone = 0

    user.save!

    Audit.log :actor => '<system>', :action => 'user.create', :user_name => 'admin', :desc => "Created the default user 'admin'"

    group = Group.create(name: "administrators", alert: false)
    group.users << user
    group.save

    Audit.log :actor => '<system>', :action => 'group.create', :group_name => 'administrators', :desc => "Created the default group 'administrators'"
  end

  def archive_mode?
    LicenseManager.instance.check(:archive)
  end

  def ensure_signatures
    if archive_mode?
      trace :info, "This is an archive installation. Signatures are not created automatically."
      return
    end

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

    dump_network_signature
  end

  # dump the signature for NIA, Anon etc to a file
  def dump_network_signature
    File.open(Config.instance.cert('rcs-network.sig'), 'wb') do |f|
      f.write Signature.where(scope: 'network').first.value
    end
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

    host = "127.0.0.1"
    db_name = 'admin'

    [27017, 27018, 27019].each do |port|
      DB.instance.open(host, port, db_name) { |db| db.command(logRotate: 1) }
    end

    true
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
