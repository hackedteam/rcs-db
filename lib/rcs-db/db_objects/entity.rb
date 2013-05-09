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
  # Find all the entities (that are not "other_entity") in the same path of "other_entity",
  # for example all the entities in the same "operation" of the given one
  scope :same_path_of, lambda { |other_entity| where(:_id.ne => other_entity._id, :path => other_entity.path.first) }

  after_create :create_callback
  before_destroy :destroy_callback
  after_update :notify_callback

  def create_callback
    # make item accessible to the users of the parent operation
    parent = ::Item.find(self.path.last)
    self.users = parent.users

    # notify (only real entities)
    unless level.eql? :ghost
      push_new_entity self
      alert_new_entity
    end
  end

  def push_new_entity(entity)
    RCS::DB::PushManager.instance.notify('entity', {id: entity._id, action: 'create'})
  end

  def push_modify_entity(entity)
    RCS::DB::PushManager.instance.notify('entity', {id: entity._id, action: 'modify'})
  end

  def push_destroy_entity(entity)
    RCS::DB::PushManager.instance.notify('entity', {id: entity._id, action: 'destroy'})
  end

  def alert_new_entity
    RCS::DB::Alerting.new_entity(self)
  end

  def notify_callback
    # we are only interested if the properties changed are:
    interesting = ['name', 'desc', 'position', 'handles', 'links']
    return if not interesting.collect {|k| changes.include? k}.inject(:|)

    push_modify_entity self
  end

  def destroy_callback

    # remove all the links in linked entities
    self.links.each do |link|
      oe = link.linked_entity
      next unless oe
      oe.links.connected_to(self).destroy_all
      push_modify_entity oe
    end

    self.photos.each do |photo|
      del_photo photo
    end

    push_destroy_entity self
  end

  def merge(merging)
    raise "cannot merge a target over a person" if merging.type == :target
    raise "cannot merge different type of entities" unless [:person, :target].include? self.type and [:person, :target].include? merging.type

    trace :debug, "Merging entities: #{merging.name} -> #{self.name}"

    # merge the name and description only if empty
    self.name = merging.name if self.name.nil? or self.name.eql? ""
    self.desc = merging.desc if self.desc.nil? or self.desc.eql? ""

    # merge the photos
    self.photos = self.photos + merging.photos

    # merge the handles
    merging.handles.each do |handle|
      self.handles << handle
    end

    # move the links of the merging to the mergee
    RCS::DB::LinkManager.instance.move_links(from: merging, to: self)

    # remove links to the merging entity
    RCS::DB::LinkManager.instance.del_link(from: merging, to: self)

    # merging is always done by the user
    self.level = :manual

    # save the mergee and destroy the merger
    self.save
    merging.destroy

    push_modify_entity self
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

  def latitude_and_longitude
    return unless self.position
    hsh = position.to_hsh
    {latitude: hsh[:y], longitude: hsh[:x]}
  end

  def last_position
    return unless latitude_and_longitude
    latitude_and_longitude.merge position_attr.symbolize_keys
  end

  def self.check_intelligence_license
    LicenseManager.instance.check :intelligence
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
    return nil if check_intelligence_license

    # use the fulltext (kw) search to be fast
    Evidence.collection_class(target_id).where({type: 'addressbook', :kw.all => handle.keywords }).each do |e|
      @@acc_cache.store(search_key, e[:data]['name'])
      return e[:data]['name']
    end

    return nil
  rescue Exception => e
    trace :warn, "Cannot resolve entity name: #{e.message}"
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

    if self.links.size >= 2
      self.level = :automatic
      self.save

      # notify the new entity
      push_new_entity self
      alert_new_entity

      # update all its link to automatic
      self.links.where(level: :ghost).each do |link|
        RCS::DB::LinkManager.instance.edit_link(from: self, to: link.linked_entity, level: :automatic)
      end
    end
  end

  def create_or_update_handle type, handle, name
    existing_handle = handles.where(type: type, handle: handle).first

    if existing_handle
      if existing_handle.empty_name?
        trace :info, "Modifying handle [#{type}, #{handle}, #{name}] on entity: #{self.name}"
        existing_handle.update_attributes name: name
      end

      existing_handle
    else
      trace :info, "Adding handle [#{type}, #{handle}, #{name}] to entity: #{self.name}"
      # add to the list of handles
      handles.create! level: EntityHandle.default_level, type: type, name: name, handle: handle
    end
  end

  def linked_to? another_entity
    link_to_another_entity = links.connected_to(another_entity).first
    link_to_this_entity = another_entity.links.connected_to(self).first

    # TODO: also check the versus of the link and the backlink
    # versus_ary = [link_to_another_entity.versus, link_to_another_entity.versus]
    # return false unless [[:in, :out], [:out, :in], [:both, :both]].include? versus_ary

    link_to_this_entity and link_to_another_entity
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

  def self.default_level
    :automatic
  end

  def empty_name?
    "#{name}".strip.empty?
  end

  def check_intelligence_license
    LicenseManager.instance.check :intelligence
  end

  def create_callback
    return unless check_intelligence_license

    # check if other entities have the same handle (it could be an identity relation)
    RCS::DB::LinkManager.instance.check_identity(self._parent, self)
    # link any other entity to this new handle (based on aggregates)
    RCS::DB::LinkManager.instance.link_handle(self._parent, self)
  end

end


class EntityLink
  include RCS::Tracer
  include Mongoid::Document

  embedded_in :entity

  scope :connected_to, lambda { |other_entity| where(le: other_entity.id) }

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

  def linked_entity
    Entity.find le
  end

  def linked_entity= entity
    self.le = entity.id
  end

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