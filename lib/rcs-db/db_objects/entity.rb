require 'mongoid'
require 'lrucache'

require_relative '../link_manager'
require_relative '../position/proximity'
require_relative '../country_calling_codes'

#module RCS
#module DB

class Entity
  extend RCS::Tracer
  include RCS::Tracer
  include Mongoid::Document
  include Mongoid::Timestamps
  include RCS::DB::Proximity

  # this is the type of entity: target, person, position, etc
  field :type, type: Symbol

  # the level of trust of the entity (manual, automatic, ghost, suggested)
  field :level, type: Symbol

  # membership of this entity (inside operation or target)
  field :path, type: Array

  field :name, type: String
  field :desc, type: String

  # list of grid id for the photos
  field :photos, type: Array, default: []

  # last known position of a target
  field :position, type: Array
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
  index({position: "2dsphere"}, {background: true})

  store_in collection: 'entities'

  scope :targets, where(type: :target)
  scope :persons, where(type: :person)
  scope :virtuals, where(type: :virtual)
  scope :targets_or_persons, where(:type => {'$in' => [:person, :target]})
  scope :positions, where(type: :position)
  # Find all the entities (that are not "other_entity") in the same path of "other_entity",
  # for example all the entities in the same "operation" of the given one
  scope :same_path_of, lambda { |other_entity| where(:_id.ne => other_entity._id, :path => other_entity.path.first) }
  scope :path_include, lambda { |item| where('path' => {'$in' =>[item.respond_to?(:_id) ? item._id : Moped::BSON::ObjectId.from_string(item.to_s)]}) }
  scope :with_handle, lambda { |type, value|
    if type.to_s != 'phone'
      elem_match(handles: {type: type, handle: value})
    else
      parsed = RCS::DB::CountryCallingCodes.number_without_calling_code(value)
      if parsed == value
        parsed = value.gsub(/[^0-9]/, '')
        regexp = /^#{parsed.split('').join('\s{0,1}\-{0,1}')}$/
        elem_match(handles: {type: type, handle: regexp})
      else
        parsed.gsub!(/[^0-9]/, '')
        regexp = /#{parsed.split('').join('\s{0,1}\-{0,1}')}$/
        elem_match(handles: {type: type, handle: regexp})
      end
    end
  }

  after_create :create_callback
  before_destroy :destroy_callback
  after_update :notify_callback

  def create_callback
    # make item accessible to the users of the parent operation
    parent = ::Item.find(self.path.first)
    self.users = parent.users

    # notify (only real entities)
    unless level.eql? :ghost
      push_new_entity
      alert_new_entity
    end

    link_similar_position
    link_target_entities_passed_from_here
  end

  # If the current entity is a position entity (type :position)
  # and has been created manually, search for other entities (type :position)
  # that may refer to the same location and link them with a "identity" link
  def link_similar_position
    return if type != :position
    return if level != :manual

    self.class.same_path_of(self).positions_within(position, 100).each do |other_entity|
      next unless to_point.similar_to? other_entity.to_point
      RCS::DB::LinkManager.instance.add_link from: self, to: other_entity, level: :automatic, type: :identity, versus: :both
    end
  end

  # If the current entity is a position entity (type :position)
  # search all the entities (type :target) that have been here
  def link_target_entities_passed_from_here
    return if type != :position

    operation_id = path.first

    Entity.targets.path_include(operation_id).each do |target_entity|
      aggregate_class = Aggregate.target target_entity.target_id
      next if aggregate_class.empty?

      aggregate_class.positions_within(position).each do |ag|
        next unless to_point.similar_to? ag.to_point

        link_params = {from: target_entity, to: self, level: :automatic, type: :position, versus: :out, info: ag.info}
        RCS::DB::LinkManager.instance.add_link link_params
      end
    end
  end

  def target_id
    return if type != :target
    path[1]
  end

  # Add an item of type "entity" to the PushQueue
  # @note: Do NOT add "ghost" entities because the client console shouldn't show them
  def self.push_notify entity, action
    return if entity.type == :ghost

    RCS::DB::PushManager.instance.notify('entity', {id: entity._id, action: "#{action}"})
  end

  def push_new_entity
    self.class.push_notify self, :create
  end

  def push_modify_entity
    self.class.push_notify self, :modify
  end

  def push_destroy_entity
    self.class.push_notify self, :destroy
  end

  def alert_new_entity
    RCS::DB::Alerting.new_entity(self)
  end

  def notify_callback
    # we are only interested if the properties changed are:
    interesting = ['name', 'desc', 'position', 'handles', 'links']
    return if not interesting.collect {|k| changes.include? k}.inject(:|)

    push_modify_entity
  end

  def destroy_callback

    # remove all the links in linked entities
    self.links.each do |link|
      oe = link.linked_entity
      next unless oe
      oe.links.connected_to(self).destroy_all
      oe.push_modify_entity
    end

    self.photos.each do |photo|
      del_photo photo
    end

    push_destroy_entity
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

    push_modify_entity
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

  def photo_data photo_id
    RCS::DB::GridFS.get(photo_id, path.last.to_s).read
  end

  def last_position=(hash)
    self.position = [hash[:longitude], hash[:latitude]]
    self.position_attr = {time: hash[:time], accuracy: hash[:accuracy]}
  end

  def latitude_and_longitude
    return unless self.position
    {latitude: position[1], longitude: position[0]}
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
    path_filter = path ? {path: path} : {}

    entity = Entity.with_handle(type, handle).where(path_filter).first
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

  def peer_versus entity_handle
    # only targets have aggregates
    return [] unless type.eql? :target

    # search for communication in one direction
    criteria = Aggregate.target(path.last).in(:type => entity_handle.aggregate_types).where('data.peer' => entity_handle.handle)
    versus = []
    versus << :in if criteria.where('data.versus' => :in).exists?
    versus << :out if criteria.where('data.versus' => :out).exists?

    trace :debug, "Searching for #{entity_handle.handle} (#{entity_handle.type}) on #{self.name} -> #{versus}"

    return versus
  end

  def promote_ghost
    return unless self.level.eql? :ghost

    if self.links.size >= 2
      self.level = :automatic
      self.desc = 'Represent a person known by two or more targets'
      self.save

      # notify the new entity
      push_new_entity
      alert_new_entity

      # update all its link to automatic
      self.links.where(level: :ghost).each do |link|
        RCS::DB::LinkManager.instance.edit_link(from: self, to: link.linked_entity, level: :automatic)
      end
    end
  end

  def create_or_update_handle type, handle, name = nil
    existing_handle = handles.where(type: type, handle: handle).first

    if existing_handle
      if existing_handle.empty_name? && name
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

  def linked_to? another_entity, options = {}
    filter = {}
    filter[:type] = options[:type] if options[:type]
    filter[:level] = options[:level] if options[:level]

    link_to_another_entity = links.connected_to(another_entity).where(filter).first
    link_to_this_entity = another_entity.links.connected_to(self).where(filter).first

    linked = !!(link_to_this_entity && link_to_another_entity)

    return false unless linked

    # Check the versus of the link and the backlink
    versus_ary = [link_to_this_entity.versus, link_to_another_entity.versus]
    return false unless [[:in, :out], [:out, :in], [:both, :both]].include? versus_ary

    true
  end

  def self.flow params
    start_time = Time.now # for debugging

    # aggregate all the entities by their handles' handle
    # so if 2 entities share the same handle you'll get {'foo.bar@gmail.com' => ['entity1_id', 'entity2_id']}
    # TODO: the type should be also considered as a key with "$handles.handle"
    match = {:_id => {'$in' => params[:entities]}}
    group = {:_id=>"$handles.handle", :entities=>{"$addToSet"=>"$_id"}}
    handles_and_entities = Entity.collection.aggregate [{'$match' => match}, {'$unwind' => '$handles' }, {'$group' => group}]
    handles_and_entities = handles_and_entities.inject({}) { |hash, h| hash[h["_id"]] = h["entities"]; hash }

    # take all the tagerts of the given entities:
    # take all the entities of type "target" and for each of these take the second id in the "path" (the "target" id)
    or_filter = params[:entities].map { |id| {id: id} }
    target_entities = Entity.targets.any_of(or_filter)
    targets = target_entities.map { |e| e.path[1] }

    days = {}
    targets.each do |target_id|
      # take all the aggregates of the selected targets
      # only the aggregates within the given time frame
      # only the aggregates with sender and peer, discard the others (with only the peer information)
      match = {'data.sender' => {'$exists' => true}, 'data.peer' => {'$exists' => true}, 'day' => {"$gte" => params[:from].to_s, "$lte" => params[:to].to_s}}
      group = {_id: {day: '$day', sender: "$data.sender", peer: "$data.peer", versus: "$data.versus"}, count: {'$sum' => "$count"}}
      aggregates = Aggregate.target(target_id).collection.aggregate [{'$match' => match}, {'$group' => group}]

      aggregates.each do |aggregate|
        data = aggregate['_id']
        count = aggregate['count']

        # repalce the handles couple with the entities' ids
        next unless handles_and_entities[data['sender']]
        next unless handles_and_entities[data['peer']]

        handles = [data['sender'], data['peer']]
        # TODO: data['versus'] can be :both??
        handles.reverse! if data['versus'] == :in

        entities_ids = handles_and_entities[handles.first].product handles_and_entities[handles.last]
        entities_ids.each do |entity_ids|
          days[data['day']] ||= {}
          days[data['day']][entity_ids] ||= 0
          days[data['day']][entity_ids] += count
        end
      end
    end

    trace :debug, "Entity#flow excecution time: #{Time.now - start_time}" if RCS::DB::Config.instance.global['PERF']

    days
  end

  def to_point
    Point.new lat: last_position[:latitude], lon: last_position[:longitude], r: last_position[:accuracy]
  end

  def fetch_address
    request = {'gpsPosition' => {"latitude" => last_position[:latitude], "longitude" => last_position[:longitude]}}
    result = RCS::DB::PositionResolver.get request
    update_attributes(name: result["address"]["text"]) unless result.empty?
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

  def aggregate_types
    if type == :phone
      [:sms, :mms, :phone]
    elsif type == :mail
      [:mail, :gmail, :outlook]
    else
      [type.to_sym]
    end
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
    Entity.find(le) rescue nil
  end

  def linked_entity= entity
    self.le = entity.id
  end

  def add_info value
    return if value.blank?

    if value.kind_of? Array
      info.concat value
      info.uniq!
    else
      return if info.include? value
      info << value
    end
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