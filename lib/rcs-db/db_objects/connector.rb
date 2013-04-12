require 'mongoid'

#module RCS
#module DB

class Connector
  include Mongoid::Document
  include Mongoid::Timestamps

  field :enabled, type: Boolean
  field :name, type: String
  field :type, type: String, default: "JSON"
  field :dest, type: String
  field :raw, type: Boolean
  field :keep, type: Boolean, default: true
  field :path, type: Array

  store_in collection: 'connectors'

  def delete_if_item(id)
    if self.path.include? id
      trace :debug, "Deleting Connector because it contains #{id}"
      self.destroy
    end
  end

  def update_path(id, path)
    if self.path.last == id
      trace :debug, "Updating Connector because it contains #{id}"
      self.path = path
      self.save
    end
  end

end

#end # ::DB
#end # ::RCS