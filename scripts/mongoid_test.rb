require 'mongoid'

class MyDoc
  include Mongoid::Document

  field :time, type: Integer
  field :text, type: String

  index :time
  index :text

  store_in :mydocs
end


class MongoidTest

  def run
      start = Time.now

      # this is required for mongoid >= 2.4.2
      ENV['MONGOID_ENV'] = 'yes'

      #Mongoid.load!(Dir.pwd + '/config/mongoid.yaml')
      Mongoid.configure do |config|
        config.master = Mongo::Connection.new("127.0.0.1", 27017, pool_size: 50, pool_timeout: 15).db('test')
      end

      puts "conn: %f" % (Time.now - start)

      m = MyDoc.new
      m.time = Time.now.to_i
      m.text = "hello"
      m.save

      puts "save: %f" % (Time.now - start)

  end

end


if __FILE__ == $0
  MongoidTest.new.run
end