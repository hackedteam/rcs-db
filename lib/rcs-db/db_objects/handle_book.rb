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

  # Returns a list of target ids that have communicated with the given account
  def self.targets(type, handle)
    valid_type = Aggregate.aggregate_type_to_handle_type(type).to_sym
    handle_regexp = EntityHandle.handle_regexp_for_queries(valid_type, handle)

    doc = where(type: valid_type, handle: handle_regexp).first

    doc ? doc.targets : []
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
  def self.entities_of_targets(type, handle, exclude: nil)
    list = targets(type, handle)

    list.map! do |target_id|
      entity = Entity.targets.where(path: target_id).first
      entity and entity != exclude ? entity : nil
    end

    list.compact!

    list
  end

  # Remove the given target id everywhere.
  # @note: This is performed with a bulk update so the mongoid callbacks will not be fired.
  def self.remove_target(target)
    target_id = target.respond_to?(:id) ? target.id : Moped::BSON::ObjectId(target)
    where(targets: target_id).pull(:targets, target_id)
  end
end
