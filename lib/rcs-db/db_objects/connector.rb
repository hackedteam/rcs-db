require 'mongoid'
require 'rcs-common/trace'

class Connector
  extend RCS::Tracer
  include RCS::Tracer
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

  index enabled: 1

  def delete_if_item(id)
    return unless path.include?(id)
    trace :debug, "Deleting Connector because it contains #{id}"
    destroy
  end

  def update_path(id, path)
    return if self.path.last != id
    trace :debug, "Updating Connector because it contains #{id}"
    update_attributes! path: path
  end
end
