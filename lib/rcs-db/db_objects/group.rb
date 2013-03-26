require 'mongoid'

#module RCS
#module DB

class Group
  include Mongoid::Document
  include Mongoid::Timestamps
  extend RCS::Tracer
  include RCS::Tracer

  field :name, type: String
  field :alert, type: Boolean
  
  validates_uniqueness_of :name, :message => "GROUP_ALREADY_EXISTS"

  has_and_belongs_to_many :users, dependent: :nullify, autosave: true, after_add: :add_user_callback, after_remove: :remove_user_callback
  has_and_belongs_to_many :items, dependent: :nullify, autosave: true, after_add: :add_item_callback, after_remove: :remove_item_callback

  index({name: 1}, {background: true})
  
  store_in collection: 'groups'

  def add_user_callback(user)
    Thread.new do
      # user added to a group, we have to put in every item and entity of this group
      self.items.each do |operation|
        operation.users << user
        ::Item.any_in({path: [operation._id]}).each do |item|
          trace :debug, "Adding user #{user.name} to item #{item.name}"
          item.users << user
        end
        ::Entity.any_in({path: [operation._id]}).each do |ent|
          trace :debug, "Adding user #{user.name} to entity #{ent.name}"
          ent.users << user
        end
      end
    end
  end

  def remove_user_callback(user)
    Thread.new do
      # user removed from a group, we have to delete in every item and entity of this group
      self.items.each do |operation|
        operation.users.delete(user)
        ::Item.any_in({path: [operation._id]}).each do |item|
          trace :debug, "Removing user #{user.name} from item #{item.name}"
          item.users.delete(user)
        end
        ::Entity.any_in({path: [operation._id]}).each do |ent|
          trace :debug, "Removing user #{user.name} from entity #{ent.name}"
          ent.users.delete(user)
        end
      end
    end
  end

  def add_item_callback(operation)
    Thread.new do
      # operation added to a group, we have to put the users in all items and entities
      operation.users += self.users
      ::Item.any_in({path: [operation._id]}).each do |item|
        trace :debug, "Adding these users to item #{item.name}: #{self.users.collect {|u| u.name}.inspect}"
        item.users += self.users
      end
      ::Entity.any_in({path: [operation._id]}).each do |ent|
        trace :debug, "Adding these users to entity #{ent.name}: #{self.users.collect {|u| u.name}.inspect}"
        ent.users += self.users
      end
    end
  end

  def remove_item_callback(operation)
    Thread.new do
      # operation removed from a group, we have to remove the users in all items and entities
      self.users.each do |user|
        operation.users.delete(user)
      end
      ::Item.any_in({path: [operation._id]}).each do |item|
        self.users.each do |user|
          trace :debug, "Removing user #{user.name} from item #{item.name}"
          item.users.delete(user)
        end
      end
      ::Entity.any_in({path: [operation._id]}).each do |ent|
        self.users.each do |user|
          trace :debug, "Removing user #{user.name} from item #{ent.name}"
          ent.users.delete(user)
        end
      end
    end
  end

  def self.rebuild_access_control
    # for each operation in each group, search the items of that operation and add
    # the users of this group
    Group.each do |group|
      group.items.each do |operation|
        operation.users = group.users
        ::Item.any_in({path: [operation._id]}).each do |item|
          item.users = group.users
        end
        ::Entity.any_in({path: [operation._id]}).each do |ent|
          ent.users = group.users
        end
      end
    end
  end

end

#end # ::DB
#end # ::RCS
