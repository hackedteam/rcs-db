require 'mongoid'

#module RCS
#module DB

class Alert
  include RCS::Tracer
  include Mongoid::Document
  include Mongoid::Timestamps

  field :enabled, type: Boolean
  field :type, type: String
  field :suppression, type: Integer
  field :tag, type: Integer
  field :path, type: Array
  field :action, type: String
  field :evidence, type: String
  field :keywords, type: String
  field :last, type: Integer

  index :enabled
  index :user_id

  store_in :alerts

  belongs_to :user
  embeds_many :logs, class_name: "AlertLog"

  def delete_if_item(id)
    if self.path.include id
      trace :debug, "Deleting Alert because it contains #{id}"
      self.destroy
    end
  end

end


class AlertLog
  include Mongoid::Document

  field :time, type: Integer
  field :path, type: Array
  field :evidence, type: Array

  embedded_in :alert
end

class AlertQueue
  include Mongoid::Document

  field :alert, type: Array
  field :evidence, type: Array
  field :path, type: Array
  field :to, type: String
  field :subject, type: String
  field :body, type: String

  store_in :alertqueue
end


#end # ::DB
#end # ::RCS