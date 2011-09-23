require 'mongoid'

#module RCS
#module DB

class Backup
  include Mongoid::Document
  include Mongoid::Timestamps

  field :enabled, type: Boolean
  field :what, type: String
  field :when, type: Hash
  field :name, type: String
  field :lastrun, type: Integer
  field :status, type: String

  store_in :backups
end

#end # ::DB
#end # ::RCS