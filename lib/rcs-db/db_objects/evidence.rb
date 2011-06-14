require 'mongoid'

#module RCS
#module DB

class Evidence

  def self.collection_name(target)
    "evidence.#{target}"
  end

  def self.collection_class(target)

classDefinition = <<END
  class Evidence_#{target}
    include Mongoid::Document

    field :acquired, type: Integer
    field :received, type: Integer
    field :type, type: String
    field :relevance, type: Integer
    field :blotter, type: Boolean
    field :item, type: Array         # backdoor BSON_ID
    field :data, type: Hash

    store_in Evidence.collection_name('#{target}')
  end
END
    
    classname = "Evidence_#{target}"
    
    if self.const_defined? classname.to_sym
      klass = eval classname
    else
      eval classDefinition
      klass = eval classname
    end
    
    return klass
  end

end

#end # ::DB
#end # ::RCS