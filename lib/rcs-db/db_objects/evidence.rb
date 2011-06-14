require 'mongoid'

#module RCS
#module DB

class Evidence
  include Mongoid::Document

  field :acquired, type: Integer
  field :received, type: Integer
  field :type, type: String
  field :relevance, type: Integer
  field :blotter, type: Boolean
  field :item, type: Array         # backdoor BSON_ID
  field :data, type: Hash

  def self.collection_class(target)
    classname = "Evidence_#{target}"
    if self.const_defined? classname.to_sym
      klass = eval classname
    else
      klass = eval("#{classname} = Class.new Evidence")
      klass.store_in classname.downcase.sub(/_/, '.')
    end

    return klass
  end

end

#end # ::DB
#end # ::RCS