# For each handle (that is represented by the couple type and handle)
# the is a list of target ids that have communicated with it.
#
class HandleBook
  include Mongoid::Document
  include Mongoid::Timestamps

  store_in collection: 'peer_book'

  field :type, type: Symbol
  field :handle, type: String
  field :targets, type: Array, default: []

  index({type: 1, handle: 1}, {background: true, unique: true})

  after_save do
    destroy if targets.blank?
  end

  # Returns a list of target that have communicated with the given account
  # @note: If the target is missing, its id is removed from the list
  def self.targets_that_communicate_with(type, handle, clean_up: true)
    valid_type = Aggregate.aggregate_type_to_handle_type(type).to_sym
    handle_regexp = EntityHandle.handle_regexp_for_queries(valid_type, handle)

    doc = where(type: valid_type, handle: handle_regexp).first

    return [] unless doc

    results = doc.targets.dup

    results.map! do |target_id|
      target = Item.targets.where(_id: target_id).first

      doc.targets.delete(target_id) if target.nil? and clean_up

      target
    end

    doc.save

    results.compact!
    results
  end

  def self.insert_or_update(type, handle, target_id)
    valid_type = Aggregate.aggregate_type_to_handle_type(type).to_sym
    target_id = Moped::BSON::ObjectId(target_id)

    document = find_or_initialize_by(type: valid_type, handle: handle)

    unless document.targets.include?(target_id)
      document.targets << target_id
    end

    document.save
  end

  # Returns a list of (target) entities that have communicated with the given account
  def self.entities_that_communicate_with(type, handle, exclude: nil)
    list = targets_that_communicate_with(type, handle)

    list.map! do |target|
      entity = Entity.targets.where(path: target.id).first
      entity and entity != exclude ? entity : nil
    end

    list.compact!
    list
  end

  # Remove the given target id everywhere.
  # @note: This is performed with a bulk update so the mongoid callbacks will not be fired.
  def self.remove_target(target)
    target_id = target.respond_to?(:id) ? target.id : Moped::BSON::ObjectId(target)
    result = where(targets: target_id).pull(:targets, target_id)
    where(targets: []).destroy_all if result and result['n'] > 0
  end

  def self.rebuild
    destroy_all

    Item.targets.each do |target|
      handles = Aggregate.target(target).all.map do |agg|
        type, handle = agg.type, agg.data['peer']
        (type.blank? or handle.blank?) ? nil : [type.downcase.to_sym, handle]
      end

      handles.compact!

      handles.uniq!

      handles.each { |values| insert_or_update(values[0], values[1], target.id) }
    end
  end
end
