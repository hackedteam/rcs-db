require 'mongoid'
require 'mongoid_spacial'

#module RCS
#module DB

class Entity
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Spacial::Document

  # this is the type of entity: target, person, position, etc
  field :type, type: Symbol

  # the level of trust of the entity (manual, automatic, suggested, ghost)
  field :level, type: Symbol

  # membership of this entity (inside operation or target)
  field :path, type: Array

  field :name, type: String
  field :desc, type: String

  # list of grid id for the photos
  field :photos, type: Array, default: []

  # used by the intelligence module to know what to analyze
  field :analyzed, type: Hash, default: {handles: false, handles_last: 0}

  # last known position of a target
  # using geospatial index in mongodb
  field :position, type: Array, spacial: {lat: :latitude, lng: :longitude}
  # position_addr contains {time, accuracy}
  field :position_attr, type: Hash, default: {}

  embeds_many :handles, class_name: "EntityHandle"

  index :name
  index :type
  index :path
  index "handles.type"
  index "handles.handle"
  index "analyzed.handles"
  spacial_index :position

  store_in :entities

  scope :targets, where(type: :target)
  scope :persons, where(type: :person)
  scope :positions, where(type: :position)

  after_create :create_callback
  before_destroy :destroy_callback
  after_update :notify_callback

  def create_callback
    # make item accessible to the users
    parent = ::Item.find(self.path.last)
    RCS::DB::SessionManager.instance.add_accessible_item(parent, self)

    RCS::DB::PushManager.instance.notify('entity', {id: self._id, action: 'create'})
  end

  def notify_callback
    # we are only interested if the properties changed are:
    interesting = ['name', 'desc', 'last_position']
    return if not interesting.collect {|k| changes.include? k}.inject(:|)

    RCS::DB::PushManager.instance.notify('entity', {id: self._id, action: 'modify'})
  end

  def destroy_callback
    RCS::DB::PushManager.instance.notify('entity', {id: self._id, action: 'destroy'})
  end

  def merge(merging)
    raise "cannot merge different type of entities" unless self.type == merging.type
    raise "cannot merge entities belonging to different targets" unless self.path == merging.path

    # merge the name and description only if empty
    self.name = merging.name if self.name.nil? or self.name.eql? ""
    self.desc = merging.desc if self.desc.nil? or self.desc.eql? ""

    # merge the photos
    self.photos = self.photos + merging.photos

    # merge the handles
    merging.handles.each do |handle|
      self.handles << handle
    end

    #merge the positions
    merging.positions.each do |pos|
      self.positions << pos
    end

    # merge the current position only if newer
    self.current_position = merging.current_position if self.current_position.time < merging.current_position.time

    # save the mergee and destroy the merger
    self.save
    merging.destroy
  end

  def add_photo(content)
    # put the content in the grid collection of the target owning this entity
    id = RCS::DB::GridFS.put(content, {filename: self[:_id].to_s}, self.path.last.to_s)

    self.photos ||= []
    self.photos << id.to_s
    self.save

    return id
  end

  def del_photo(id)
    self.photos.delete(id)
    RCS::DB::GridFS.delete(id, self.path.last.to_s)
    self.save
  end

  def add_place(params)
    place = Entity.create(name: params[:name]) do |ent|
      ent.type = :position
      ent.level = :manual
      # same path as the belonging entity
      ent.path = self.path.dup
      ent.position = {latitude: params[:latitude], longitude: params[:longitude]}
      ent.position_attr = {accuracy: params[:accuracy]}
    end


  end

  def last_position=(hash)
    self.position = {latitude: hash[:latitude], longitude: hash[:longitude]}
    self.position_attr = {time: hash[:time], accuracy: hash[:accuracy]}
  end

  def last_position
    return {lat: self.position[:latitude], lng: self.position[:longitude], time: self.position_attr[:time], accuracy: self.position_attr[:accuracy]}
  end

  def self.from_handle(type, handle, target_id = nil)

    return nil unless handle

    type = 'phone' if ['call', 'sms', 'mms'].include? type
    # find if there is an entity owning that handle
    entity = Entity.where({"handles.type" => type, "handles.handle" => handle}).first
    return entity.name if entity

    # if no target (scope) is provided, don't search in the addressbook
    return nil unless target_id

    # use the fulltext (kw) search to be fast
    Evidence.collection_class(target_id).where({type: 'addressbook', :kw.all => handle.keywords }).each do |e|
      return e[:data]['name']
    end

    return nil
  end

end


class EntityHandle
  include Mongoid::Document
  include Mongoid::Timestamps

  embedded_in :entity

  # the level of trust of the entity
  field :level, type: Symbol

  field :type, type: Symbol
  field :name, type: String
  field :handle, type: String
end



#end # ::DB
#end # ::RCS