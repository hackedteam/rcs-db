require 'mongoid'

#module RCS
#module DB

class Collector
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :desc, type: String
  field :type, type: String
  field :address, typs: String
  field :internal_address, typs: String
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

  index :name
  index :address
  index :internal_address

  store_in :collectors

  after_destroy :drop_log_collection

  protected

  def drop_log_collection
    Mongoid.database.drop_collection CappedLog.collection_name(self._id.to_s)
  end

  public

  def config
    # get the next hop collector
    next_hop = Collector.find(self.prev[0]) if self.prev[0]
    (next_hop and next_hop.address.length > 0) ? next_hop.address + ':80' : '-'
  end

  def self.collector_login(instance, version, ext_address, local_address)

    coll = Collector.where({type: 'local'}).any_in({instance: [instance, 'MIGRATED']}).first

    # the collector does not exist, check the licence and create it
    if coll.nil?
      raise 'LICENSE_LIMIT_EXCEEDED' unless RCS::DB::LicenseManager.instance.check :collectors

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
      # overwrite the instance to remove the 'MIGRATED'
      coll.instance = instance
      coll.internal_address = local_address
      # update the version (can change after RCS upgrade)
      coll.version = version
      coll.save
    end

  end
end


#end # ::DB
#end # ::RCS