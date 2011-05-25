require 'mongoid'

#module RCS
#module DB

class Alert
  include Mongoid::Document
  include Mongoid::Timestamps

  field :type, type: String
  field :evidence, type: String
  field :keyword, type: String
  field :suppression, type: Integer
  field :priority, type: Integer
  field :path, type: Array

  store_in :alerts

  belongs_to :user
  embeds_many :alert_logs, class_name: "AlertLog"
end


class AlertLog
  include Mongoid::Document

  field :time, type: Integer
  field :path, type: Array
  field :evidence, type: Array

  embedded_in :alert
end

#end # ::DB
#end # ::RCS