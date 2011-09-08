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
  field :port, type: Integer
  field :instance, type: String
  field :poll, type: Boolean
  field :version, type: Integer
  field :configured, type: Boolean

  field :next, type: Array
  field :prev, type: Array

  store_in :collectors

  after_destroy :drop_log_collection

  protected

  def drop_log_collection
    Mongoid.database.drop_collection CappedLog.collection_name(self._id.to_s)
  end

  public
  def self.collector_login(instance, address)

    coll = Collector.where({instance: instance}).first

    # the collector does not exist, check the licence and create it
    if coll.nil?
      raise 'LICENSE_LIMIT_EXCEEDED' unless RCS::DB::LicenseManager.instance.check :collectors

      coll = Collector.new
      coll.type = 'local'
      coll.instance = instance
      coll.name = 'Collector Node'
      coll.desc = address
      coll.poll = false
      coll.save
      
    end

  end
end


#end # ::DB
#end # ::RCS