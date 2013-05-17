require 'spec_helper'
require_db 'db_layer'
require_db 'rest'
require_db 'rest/entity'

module RCS
module DB

  describe EntityController do

    use_db

    let!(:operation) { Item.create!(name: 'testoperation', _kind: :operation, path: [], stat: ::Stat.new) }

    # target factory
    def create_target name
      Item.create! name: "#{name}", _kind: :target, path: [operation.id], stat: ::Stat.new
    end

    def create_or_find_entity name, type, handles
      if type == :target
        entity = Entity.where(name: name, type: :target).first
      else
        entity = Entity.create! name: name, type: type, level: :ghost, path: [operation.id]
      end

      handles.each do |handle|
        entity.handles.create! level: :automatic, type: 'phone', handle: handle
      end

      entity
    end

    # aggregate factory
    def create_aggregate target, day, count, data
      Aggregate.target(target).create! day: Time.parse("#{day}"), type: 'sms', aid: 'agent_id', count: count.to_i, data: data
    end

    before do
      # skip check of current user privileges
      subject.stub :require_auth_level

      # stub the #ok method and then #not_found methods
      subject.stub(:ok) { |query, options| query }
      subject.stub(:not_found) { |message| message }
    end

    describe '#flow' do

      def flow_with_params from, to, entities
        subject.instance_variable_set '@params', entities: entities, from: Time.parse(from), to: Time.parse(to)
        subject.flow
      end

      before do
        alice_target = create_target 'alice'
        @alice = create_or_find_entity 'alice', :target, ['alice_number']
        @bob = create_or_find_entity 'bob', :person, ['bob_number']

        create_aggregate alice_target, '20130501', 42, {'sender' => 'alice_number', 'peer' => 'bob_number', 'versus' => :out}
        create_aggregate alice_target, '20130501', 4, {'sender' => 'alice_number', 'peer' => 'bob_number', 'versus' => :in}
        create_aggregate alice_target, '20130510', 7, {'sender' => 'alice_number', 'peer' => 'bob_number', 'versus' => :out}
      end

      it 'works when the other entity is not passed' do
        result = flow_with_params '20130501', '20131201', [@alice.id]
        expect(result["2013-05-01 00:00:00 +0200"]).to be_blank
        expect(result["2013-05-10 00:00:00 +0200"]).to be_blank
      end

      it 'works when all the entities are passed' do
        result = flow_with_params '20130501', '20131201', [@alice.id, @bob.id]
        expect(result["2013-05-01 00:00:00 +0200"]).to eql [@alice.id, @bob.id]=>42, [@bob.id, @alice.id]=>4
        expect(result["2013-05-10 00:00:00 +0200"]).to eql [@alice.id, @bob.id]=>7
      end

      it 'works when the timeframe is restricted' do
        result = flow_with_params '20130509', '20130510', [@alice.id, @bob.id]
        expect(result["2013-05-01 00:00:00 +0200"]).to be_blank
        expect(result["2013-05-10 00:00:00 +0200"]).to eql [@alice.id, @bob.id]=>7
      end
    end
  end

end
end
