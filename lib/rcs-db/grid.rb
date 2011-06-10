require 'mongo'
require 'mongoid'

# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

class GridFS
  include Singleton
  include RCS::Tracer
  
  def initialize
    connect
  end
  
  def connect
    begin
      @grid = Mongo::Grid.new Mongoid.database
    rescue Exception => e
      trace :fatal, "Cannot connect to MongoDB: " + e.message
    end
  end
  
  def put(content, opts = {})
    begin
      return @grid.put(content, opts)
    rescue Exception => e
      # TODO handle the correct exception
      #connect
    end
  end
  
  def get(id)
    begin
      return @grid.get BSON::ObjectId.from_string(id)
    rescue Exception => e
      # TODO handle the correct exception
      #connect
    end
  end

  def delete(id)
    begin
      return @grid.delete BSON::ObjectId.from_string(id)
    rescue Exception => e
      # TODO handle the correct exception
      #connect
    end

    return false
  end
  
  def get_by_filename(filename)
    begin
      files = @db.collection("fs.files")
      return files.find(:filename => filename, :fields => ["_id"]).all
    rescue Exception => e
      # TODO handle the correct exception
      #connect
    end
  end
end

end # ::DB
end # ::RCS