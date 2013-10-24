require 'mongoid'

#module RCS
#module DB

class Collector
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :desc, type: String
  field :type, type: String
  field :address, type: String
  field :internal_address, type: String
  field :port, type: Integer
  field :instance, type: String
  field :poll, type: Boolean
  field :version, type: Integer
  field :configured, type: Boolean, default: false
  field :upgradable, type: Boolean, default: false

  # used in case of crisis
  field :good, type: Boolean, default: true

  field :next, type: Array
  field :prev, type: Array

  index({name: 1}, {background: true})
  index({address: 1}, {background: true})
  index({internal_address: 1}, {background: true})

  scope :remote, where(type: 'remote')
  scope :local, where(type: 'local')

  store_in collection: 'collectors'

  after_destroy :drop_log_collection
  after_create :create_log_collection

  protected

  def drop_log_collection
    CappedLog.collection_class(self._id.to_s).collection.drop
  end

  def create_log_collection
    CappedLog.collection_class(self._id.to_s).create_capped_collection
  end

  public

  def config
    # get the next hop collector
    next_hop = Collector.find(self.prev[0]) if self.prev[0]
    (next_hop and next_hop.address.length > 0) ? next_hop.address + ':80' : '-'
  end

  def self.collector_login(instance, version, ext_address, local_address)

    coll = Collector.where({type: 'local'}).any_in({instance: [instance]}).first

    # the collector does not exist, check the licence and create it
    if coll.nil?
      raise 'LICENSE_LIMIT_EXCEEDED' unless LicenseManager.instance.check :collectors

      coll = Collector.new
      coll.type = 'local'
      coll.instance = instance
      coll.name = "Collector Node on #{local_address}"
      coll.desc = "Collector Node on #{local_address}"
      coll.internal_address = local_address
      coll.address = ext_address
      coll.version = version
      coll.poll = false
      coll.next = [nil]
      coll.prev = [nil]
      coll.save
    else
      # the collector already exists, check if the external address is set, otherwise update it
      if coll.address.nil? or coll.address == ''
        coll.address = ext_address
      end
      # update the version (can change after RCS upgrade)
      coll.version = version
      coll.internal_address = local_address
      coll.save
    end

  end
end


#end # ::DB
#end # ::RCS