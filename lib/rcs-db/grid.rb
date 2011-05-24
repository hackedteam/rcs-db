# from RCS::Common
require 'rcs-common/trace'

require 'mongo'

module RCS
module DB

class GridFS
  include Singleton
  include RCS::Tracer
  
  def initialize
    @db = Mongo::Connection.new.db('rcs')
    @grid = Mongo::Grid.new(@db)
  end
  
  def put(filename, content)
    puts content.inspect
    puts filename.inspect
    return @grid.put(content, filename)
  end
  
  def get(id)
    return @grid.get(id)
  end
  
  def get_by_filename(filename)
    files = @db.collection("fs.files")
    return files.find(:filename => filename, :fields => ["_id"]).all
  end
end

end # ::DB
end # ::RCS