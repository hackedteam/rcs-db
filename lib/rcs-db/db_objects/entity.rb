require 'mongoid'
require 'mongoid_geospatial'

require 'lrucache'

require_relative '../link_manager'

#module RCS
#module DB

class Entity
  extend RCS::Tracer
  include RCS::Tracer
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Geospatial

  # this is the type of entity: target, person, position, etc
  field :type, type: Symbol

  # the level of trust of the entity (manual, automatic, ghost)
  field :level, type: Symbol

  # membership of this entity (inside operation or target)
  field :path, type: Array

  field :name, type: String
  field :desc, type: String

  # list of grid id for the photos
  field :photos, type: Array, default: []

  # last known position of a target
  field :position, type: Point, spatial: true
  # position_addr contains {time, accuracy}
  field :position_attr, type: Hash, default: {}

  # accounts for this entity
  embeds_many :handles, class_name: "EntityHandle"
  embeds_many :links, class_name: "EntityLink"

  # for the access control
  has_and_belongs_to_many :users, :dependent => :nullify, :autosave => true, inverse_of: nil

  index({name: 1}, {background: true})
  index({type: 1}, {background: true})
  index({path: 1}, {background: true})
  index({"handles.type" => 1}, {background: true})
  index({"handles.handle" => 1}, {background: true})

  spatial_index :position

  store_in collection: 'entities'

  scope :targets, where(type: :target)
  scope :persons, where(type: :person)
  scope :positions, where(type: :position)

  after_create :create_callback
  before_destroy :destroy_callback
  after_update :notify_callback

  def create_callback
    # make item accessible to the users of the parent operation
    parent = ::Item.find(self.path.last)
    self.users = parent.users

    # notify (only real entities)
    unless level.eql? :ghost
      RCS::DB::PushManager.instance.notify('entity', {id: self._id, action: 'create'})
      RCS::DB::Alerting.new_entity(self)
    end
  end

  def notify_callback
    # we are only interested if the properties changed are:
    interesting = ['name', 'desc', 'last_position', 'handles', 'links']
    return if not interesting.collect {|k| changes.include? k}.inject(:|)

    RCS::DB::PushManager.instance.notify('entity', {id: self._id, action: 'modify'})
  end

  def destroy_callback

    # remove all the links in linked entities
    self.links.each do |link|
      oe = ::Entity.find(link.le)
      next unless oe
      oe.links.where(le: self._id).destroy_all
      RCS::DB::PushManager.instance.notify('entity', {id: oe._id, action: 'modify'})
    end

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

  def last_position=(hash)
    self.position = {latitude: hash[:latitude], longitude: hash[:longitude]}
    self.position_attr = {time: hash[:time], accuracy: hash[:accuracy]}
  end

  def last_position
    return {latitude: self.position.to_hsh[:y], longitude: self.position.to_hsh[:x], time: self.position_attr[:time], accuracy: self.position_attr[:accuracy]}
  end

  def self.name_from_handle(type, handle, target_id)

    # use a class cache
    @@acc_cache ||= LRUCache.new(:ttl => 24.hour)

    return nil unless handle

    type = 'phone' if ['call', 'sms', 'mms'].include? type

    target = ::Item.find(target_id)

    # the scope of the search (within operation)
    path = target ? target.path.first : nil

    # check if already in cache
    search_key = "#{type}_#{handle}_#{path}"
    name = @@acc_cache.fetch(search_key)
    return name if name

    # find if there is an entity owning that handle (the ghosts are from addressbook as well)
    search_query = {"handles.type" => type, "handles.handle" => handle}
    search_query['path'] = path if path

    entity = Entity.where(search_query).first
    if entity
      @@acc_cache.store(search_key, entity.name)
      return entity.name
    end

    # if the intelligence is enabled, we have all the ghost entities
    # so the above search will find them, otherwise we need to scan the addressbook
    return nil if $license['intelligence']

    # use the fulltext (kw) search to be fast
    Evidence.collection_class(target_id).where({type: 'addressbook', :kw.all => handle.keywords }).each do |e|
      @@acc_cache.store(search_key, e[:data]['name'])
      return e[:data]['name']
    end

    return nil
  end

  def peer_versus(handle, type)
    # only targets have aggregates
    return [] unless self.type.eql? :target

    versus = []

    # search for communication in one direction
    vin = Aggregate.collection_class(self.path.last).where(type: type, 'data.peer' => handle, 'data.versus' => :in).exists?
    vout = Aggregate.collection_class(self.path.last).where(type: type, 'data.peer' => handle, 'data.versus' => :out).exists?

    versus << :in if vin
    versus << :out if vout

    trace :debug, "Searching for #{handle} (#{type}) on #{self.name} -> #{versus}"

    return versus
  end

  def promote_ghost
    return unless self.level.eql? :ghost

    if self.links.size >= 1
      self.level = :automatic
      self.save

      # notify the new entity
      RCS::DB::PushManager.instance.notify('entity', {id: self._id, action: 'create'})
      RCS::DB::Alerting.new_entity(self)

      # update all its link to automatic
      self.links.where(level: :ghost).each do |link|
        le = Entity.find(link.le)
        RCS::DB::LinkManager.instance.edit_link(from: self, to: le, level: :automatic)
      end
    end
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

  after_create :create_callback

  def create_callback
    # check if other entities have the same handle (it could be an identity relation)
    RCS::DB::LinkManager.instance.check_identity(self._parent, self)
    # link any other entity to this new handle (based on aggregates)
    RCS::DB::LinkManager.instance.link_handle(self._parent, self)
  end

end


class EntityLink
  include Mongoid::Document

  embedded_in :entity

  # linked entity
  field :le, type: Moped::BSON::ObjectId

  # the level of trust of the link (manual, automatic, ghost)
  field :level, type: Symbol
  # kind of link (identity, peer, know, position)
  field :type, type: Symbol

  # time of the first and last contact
  field :first_seen, type: Integer
  field :last_seen, type: Integer

  # versus of the link (:in, :out, :both)
  field :versus, type: Symbol

  # evidence type that refers to this link
  # or info for identity relation
  field :info, type: Array, default: []

  # relevance (tag)
  field :rel, type: Integer, default: 0

  after_destroy :destroy_callback

  def add_info(info)
    return if self.info.include? info
    self.info << info
  end

  def set_versus(versus)
    # already set
    return if self.versus.eql? versus

    # first time, set it as new
    if self.versus.nil?
      self.versus = versus
      return
    end

    # they are different, so overwrite it to both
    self.versus = :both
  end

  def set_type(type)
    # :know is overwritable
    if self.type.eql? :know or not self.type
      self.type = type
    end

    self.type = type unless type.eql? :know
  end

  def set_level(level)
    # :ghost is overwritable
    if self.level.eql? :ghost or not self.level
      self.level = level
    end

    self.level = level unless level.eql? :ghost
  end

  def destroy_callback
    # if the parent is still ghost and this was the only link
    # destroy the parent since it was created only with that link
    if self._parent.level.eql? :ghost and self._parent.links.size == 0
      trace :debug, "Destroying ghost entity on last link (#{self._parent.name})"
      self._parent.destroy
    end
  end

end


#end # ::DB
#end # ::RCS