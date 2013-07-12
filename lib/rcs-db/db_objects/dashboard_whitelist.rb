require 'mongoid'
require 'rcs-common/trace'

module DashboardWhitelist

  # A Mongoid::Document class. This is to prevent
  # direct access to mongoid methods on DashboardWhitelist
  class Document
    include Mongoid::Document
    store_in collection: 'dashboard_whitelist'
    # Dashboard ids array
    field :dids, type: Array, default: []
    index dids: 1
  end

  extend self
  extend RCS::Tracer

  def bson_obj_id(string)
    Moped::BSON::ObjectId.from_string(string)
  end

  def include_item?(item)
    id = item.respond_to?(:id) ? item.id : item
    include?(id)
  end

  def include?(id)
    Document.where(dids: bson_obj_id(id)).count > 0
  end

  def rebuild
    dids = []
    User.online.only(:dashboard_ids).each { |user| dids.concat(user.dashboard_ids).uniq! }
    document = Document.first || Document.new
    document.update_attributes(dids: dids)
    dids
  end
end
