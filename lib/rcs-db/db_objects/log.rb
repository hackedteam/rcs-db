require 'mongoid'

#module RCS
#module DB

class CappedLog

  def self.collection_name(id)
    "logs.#{id}"
  end

  def self.collection_class(id)

    classDefinition = <<-END
      class CappedLog_#{id}
        include Mongoid::Document

        field :time, type: Integer
        field :type, type: String
        field :desc, type: String

        store_in CappedLog.collection_name('#{id}')
      end
    END
    
    classname = "CappedLog_#{id}"
    
    if self.const_defined? classname.to_sym
      klass = eval classname
    else
      eval classDefinition
      klass = eval classname
    end
    
    return klass
  end

  def self.dynamic_new(id)
    # make sure the collection is created
    # it can happen that after a mongorestore the empty collection is not restored.
    # we need to be sure that it is created as capped.
    # TODO: remove this when mongoid will support capped collections.
    Mongoid.database.create_collection(self.collection_name(id), {capped: true, size: 2_000_000, max: 10_000})

    klass = self.collection_class(id)
    return klass.new
  end

end

#end # ::DB
#end # ::RCS