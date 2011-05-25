# from RCS::Common
require 'rcs-common/trace'

require 'mongo'

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
      @db = Mongo::Connection.new.db('rcs')
      @grid = Mongo::Grid.new(@db)
    rescue Exception => e
      trace :fatal, "Cannot connect to MongoDB: " + e.message
    end
  end

  def put(filename, content)
    #puts content.inspect
    #puts filename.inspect
    begin
      return @grid.put(content, filename)
    rescue Exception => e
      # TODO handle the correct exception
      #connect
    end
  end
  
  def get(id)
    begin
      return @grid.get(id)
    rescue Exception => e
      # TODO handle the correct exception
      #connect
    end
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