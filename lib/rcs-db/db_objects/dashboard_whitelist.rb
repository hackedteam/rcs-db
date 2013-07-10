require 'mongoid'
require 'rcs-common/trace'

class DashboardWhitelist
  include RCS::Tracer
  extend RCS::Tracer
  include Mongoid::Document

  store_in collection: 'dashboard_whitelist'

  # Dashboard ids array
  field :dids, type: Array, default: []

  index dids: 1

  def self.bson_obj_id(string)
  	Moped::BSON::ObjectId.from_string(string)
  end

  def self.include_item?(item)
  	id = item.respond_to?(:id) ? item.id : item
  	include?(item)
  end

  def self.include?(id)
  	where(dids: bson_obj_id(id)).count > 0
  end

  # TODO
  def self.rebuild
  end
end
