require 'mongoid'

class Backup
  include Mongoid::Document
  include Mongoid::Timestamps
  include RCS::Tracer
  extend RCS::Tracer

  field :enabled, type: Boolean
  field :what, type: String
  field :when, type: Hash
  field :name, type: String
  field :lastrun, type: String
  field :status, type: String
  field :incremental, type: Boolean, default: false
  field :incremental_ids, type: Hash, :default => {}

  store_in collection: 'backups'

  def delete_if_item(id)
    if self.what[id.to_s]
      trace :debug, "Deleting Backup because it contains #{id}"
      self.destroy
    end
  end
end
