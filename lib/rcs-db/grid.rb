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
      @db = Mongoid.database
      @grid = Mongo::Grid.new @db
    rescue Exception => e
      trace :fatal, "Cannot connect to MongoDB: " + e.message
    end
  end
  
  def put(content, opts = {})
    begin
      # returns grid id
      return @grid.put(content, opts)
    rescue Exception => e
      # TODO handle the correct exception
      #connect
    end
  end
  
  def get(id)
    begin
      # returns grid IO
      return @grid.get id
    rescue Exception => e
      # TODO handle the correct exception
      #connect
    end
  end

  def delete(id)
    begin
      return @grid.delete id
    rescue Exception => e
      # TODO handle the correct exception
      #connect
    end

    return false
  end

  def delete_by_backdoor(backdoor_id)
    items = get_by_filename(backdoor_id)
    items.each {|item| delete item["_id"]}
  end
  
  def get_by_filename(filename)
    begin
      files = @db.collection("fs.files")
      return files.find({"filename" => filename}, :fields => ["_id"])
    rescue Exception => e
      # TODO handle the correct exception
      puts e.message
      #connect
    end
  end
end

end # ::DB
end # ::RCS