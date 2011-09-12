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
  field :version, type: Integer
  field :configured, type: Boolean
  field :redirection_tag, type: String

  store_in :proxies

  embeds_many :rules, class_name: "ProxyRule"

  after_destroy :drop_log_collection

  protected
  def drop_log_collection
    Mongoid.database.drop_collection CappedLog.collection_name(self._id.to_s)
  end
end


class ProxyRule
  include Mongoid::Document
  include Mongoid::Timestamps

  field :enabled, type: Boolean
  field :disable_sync, type: Boolean
  field :probability, type: Integer

  field :target_id, type: Array
  field :ident, type: String
  field :ident_param, type: String
  field :resource, type: String
  field :action, type: String
  field :action_param, type: String
  field :action_param_name, type: String

  field :_grid, type: Array

  embedded_in :proxy
end

#end # ::DB
#end # ::RCS