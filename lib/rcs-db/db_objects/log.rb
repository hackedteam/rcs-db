require 'mongoid'

#module RCS
#module DB

class CappedLog

  def self.collection_name(id)
    "logs.#{id}"
  end

  def self.collection_class(id)

    class_definition = <<-END
      class CappedLog_#{id}
        include Mongoid::Document

        field :time, type: Integer
        field :type, type: String
        field :desc, type: String

        store_in collection: CappedLog.collection_name('#{id}')

        def self.create_capped_collection
          self.mongo_session.command(create: self.collection.name, capped: true, size: 1_000_000, max: 2_000)
        end
      end
    END
    
    classname = "CappedLog_#{id}"
    
    if self.const_defined? classname.to_sym
      klass = eval classname
    else
      eval class_definition
      klass = eval classname
    end
    
    return klass
  end

  def self.dynamic_new(id)
    klass = self.collection_class(id)
    return klass.new
  end

end

#end # ::DB
#end # ::RCS