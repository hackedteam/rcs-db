require 'mongoid'
require 'rcs-common/trace'

class WatchedItem
  extend RCS::Tracer
  include Mongoid::Document

  field :iid, as: :item_id, type: Moped::BSON::ObjectId
  field :uids, as: :user_ids, type: Array, default: []

  index iid: 1

  def self.rebuild
    delete_all
    documents = {}

    User.online.only(:dashboard_ids).each do |user|
      user.dashboard_ids.each do |item_id|
        documents[item_id] ||= []
        documents[item_id] << user.id unless documents[item_id].include?(user.id)
      end
    end

    documents.each { |item_id, user_ids| create!(item_id: item_id, user_ids: user_ids) }
  end

  def self.matching(*items)
    items2id = items.inject({}) do |h, item|
      h[item.id] = item if item.respond_to?(:id)
      h
    end

    self.in(item_id: items2id.keys).each do |dw|
      item = items2id[dw.item_id]

      if item._kind == 'operation'
        Item.targets.path_include(item).each { |i| yield(i, dw.user_ids) }
      else
        yield(item, dw.user_ids)
      end
    end
  end
end
