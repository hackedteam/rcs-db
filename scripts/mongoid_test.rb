require 'mongoid'

class User
  include Mongoid::Document

  field :name, type: String

  #has_and_belongs_to_many :items, dependent: :nullify, inverse_of: nil, :autosave => true, :foreign_key => "dashboard"

  store_in collection: 'users'
end

class Item
  include Mongoid::Document

  field :name, type: String

  has_and_belongs_to_many :users, :dependent => :nullify, :autosave => true, inverse_of: nil, after_add: :callback

  store_in collection: 'items'

  #after_add :callback

  def callback(x)
    puts "CALLBACK:" + x.inspect
  end
end


class MongoidTest

  def run
      # we are standalone (no rails or rack)
      ENV['MONGOID_ENV'] = 'yes'

      # set the parameters for the mongoid.yaml
      ENV['MONGOID_DATABASE'] = 'test'
      ENV['MONGOID_HOST'] = "The-One.local:27017"

      #Mongoid.logger.level = ::Logger::DEBUG
      #Moped.logger.level = ::Logger::DEBUG

      #Mongoid.logger = ::Logger.new($stdout)
      #Moped.logger = ::Logger.new($stdout)

      Mongoid.load!('../config/mongoid.yaml', :production)

      puts "Connected to MongoDB at #{ENV['MONGOID_HOST']}"

      User.destroy_all
      Item.destroy_all

      u = User.create do |u|
        u.name = "Test user"
      end

      u2 = User.create do |u|
        u.name = "Test user 2"
      end

      i = Item.create do |i|
        i.name = "Test Item"
      end

      i2 = Item.create do |i|
        i.name = "Test Item 2"
      end

      #u.items << i

      #i.users += [u, u2]
      i.users << u2
      i.users << u
      #i.users += [u, u2]

      #i.users.in(_id: [u2._id]).delete_all
      i.users.delete(u2)
      #i2.users = i.users

      i.users.each do |x|
        puts x.inspect
      end

      puts i.users.include? u

      puts "all:"

      User.each {|i| puts i.inspect}
      Item.each {|i| puts i.inspect}

      puts "where:"

      Item.where("user.name" => u.name).each {|i| puts i.inspect}
      Item.in(user_ids: [u._id]).each {|i| puts i.inspect}

  end

end


if __FILE__ == $0
  MongoidTest.new.run
end