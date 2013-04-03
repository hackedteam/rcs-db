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
      # if already present, it will not be duplicated by mongoid
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
      # user removed from a group, it is not enough to delete it in every item and entity of this group
      # since it could be able to access that item through another group.
      # rebuild the whole access control of the operations
      self.items.each do |operation|
        trace :debug, "Rebuilding access control for #{operation.name}"
        Group.rebuild_access_control(operation)
      end
    end
  end

  def add_item_callback(operation)
    Thread.new do
      # operation added to a group, we have to put the users in all items and entities
      # if already present, it will not be duplicated by mongoid
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
      # rebuild the whole access control of the operation
      trace :debug, "Rebuilding access control for #{operation.name}"
      Group.rebuild_access_control(operation)
    end
  end

  def self.rebuild_access_control(operation)
    # remove every users from this operation
    operation.users.each do |user|
      operation.users.delete(user)
    end

    # add all the users of all the groups linked to this operation
    operation.groups.each do |group|
      operation.users += group.users
    end

    # reflect the users on items belonging to this operation
    ::Item.any_in({path: [operation._id]}).each do |item|
      item.users = operation.users
    end
    ::Entity.any_in({path: [operation._id]}).each do |ent|
      ent.users = operation.users
    end
  end

end

#end # ::DB
#end # ::RCS
