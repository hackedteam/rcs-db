require 'mongoid'
require 'rcs-common/trace'

class DashboardWhitelist
  extend RCS::Tracer
  include Mongoid::Document

  store_in collection: 'dashboard_whitelist'

  field :iid, as: :item_id, type: Moped::BSON::ObjectId
  field :cks, as: :cookies, type: Array, default: []

  index iid: 1

  def self.inject_cookies_on(*items)
    ids = items.map(&:id)
    self.in(:item_id => ids).inject({}) { |h, doc| h[doc.item_id] = doc.cookies; h }
  end

  def self.user_cookie
    filter = {:user_id.ne => nil, :cookie.ne => nil}
    Session.where(filter).only(:user_id, :cookie).inject({}) { |h, sess| h[sess.user_id] = sess.cookie; h }
  end

  def self.rebuild
    delete_all
    documents = {}

    User.online.only(:dashboard_ids).each do |user|
      cookie = user_cookie[user.id]
      next unless cookie

      user.dashboard_ids.each do |item_id|
        documents[item_id] ||= []
        documents[item_id] << cookie unless documents[item_id].include?(cookie)
      end
    end

    documents.each { |item_id, cookies| create!(item_id: item_id, cookies: cookies) }
  end
end
