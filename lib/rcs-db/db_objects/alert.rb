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
  field :entities, type: Array, default: []
  field :last, type: Integer

  index({enabled: 1}, {background: true})
  index({path: 1}, {background: true})

  store_in collection: 'alerts'

  belongs_to :user, index: true
  embeds_many :logs, class_name: "AlertLog"

  def delete_if_item(id)
    if self.path.include? id
      trace :debug, "Deleting Alert because it contains #{id}"
      self.destroy
    end
  end

  def update_path(id, path)
    if self.path.last == id
      trace :debug, "Updating Alert because it contains #{id}"
      self.path = path
      self.logs.destroy_all
      self.save
    end
  end

end


class AlertLog
  include Mongoid::Document

  field :time, type: Integer
  field :path, type: Array
  field :evidence, type: Array, default: []
  field :entities, type: Array, default: []

  embedded_in :alert
end

#end # ::DB
#end # ::RCS