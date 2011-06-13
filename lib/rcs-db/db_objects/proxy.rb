require 'mongoid'

#module RCS
#module DB

class Proxy
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :desc, type: String
  field :address, type: String
  field :redirect, type: String
  field :port, type: Integer
  field :poll, type: Boolean
  field :version, type: String
  field :configured, type: Boolean
  field :redirection_tag, type: String

  store_in :proxies

  embeds_many :rules, class_name: "ProxyRule"

  after_create :create_log_collection
  after_destroy :drop_log_collection

  protected
  def create_log_collection
    db = Mongoid.database
    db.create_collection("log." + self._id.to_s, {capped: true, size: 2_000_000, max: 10_000})
  end

  def drop_log_collection
    db = Mongoid.database
    db.drop_collection("log." + self._id.to_s)
  end
end


class ProxyRule
  include Mongoid::Document
  include Mongoid::Timestamps

  field :enabled, type: Boolean
  field :disable_sync, type: Boolean
  field :probability, type: Integer

  field :target, type: Array
  field :ident, type: String
  field :ident_param, type: String
  field :resource, type: String
  field :action, type: String
  field :action_param, type: String

  field :_grid, type: Array

  embedded_in :proxy
end

#end # ::DB
#end # ::RCS