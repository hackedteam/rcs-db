require 'mongoid'

class Item
  include Mongoid::Document
  include Mongoid::Timestamps

  # common
  field :name, type: String
  field :desc, type: String
  field :status, type: String
  field :_kind, type: String
  field :_path, type: Array

  # activity
  field :contact, type: String

  # backdoor
  field :build, type: String
  field :instance, type: String
  field :version, type: String
  field :type, type: String
  field :platform, type: String
  field :deleted, type: Boolean
  field :uninstalled, type: Boolean
  field :counter, type: Integer
  field :pathseed, type: String
  field :confkey, type: String
  field :logkey, type: String

  has_and_belongs_to_many :groups, :dependent => :nullify, :autosave => true
  
  store_in :items
end