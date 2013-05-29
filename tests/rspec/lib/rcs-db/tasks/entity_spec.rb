require 'spec_helper'
require_db 'grid'
require_db 'db_layer'
require_db 'tasks'

module RCS
module DB

  describe EntityTask do

    use_db
    silence_alerts
    enable_license
    stub_temp_folder

    let(:admin) { User.create! name: 'admin', enabled: true }

    let(:operation) do
      Item.create!(name: 'testoperation', _kind: :operation, path: [], stat: ::Stat.new).tap do |op|
        op.users << admin
      end
    end

    let(:bob) do
      target = Item.create! name: "bob", _kind: :target, path: [operation.id], stat: ::Stat.new
      entity = Entity.any_in({path: [target.id]}).first
      entity.create_or_update_handle :mail, 'mr_bob@hotmail.com', 'Mr. Bob'
      entity.create_or_update_handle :skype, 'mr.bob', 'Bob!'
      aggregate_class = Aggregate.target target
      aggregate_class.create!(day: Time.now.strftime('%Y%m%d'), type: :sms, aid: 'agent_id', count: 1, data: {peer: 'test1', versus: :in})
      aggregate_class.create!(day: Time.now.strftime('%Y%m%d'), type: :sms, aid: 'agent_id', count: 2, data: {peer: 'test2', versus: :in})
      aggregate_class.create!(day: Time.now.strftime('%Y%m%d'), type: :sms, aid: 'agent_id', count: 3, data: {peer: 'test3', versus: :in})
      aggregate_class.create!(day: Time.now.strftime('%Y%m%d'), type: :skype, aid: 'agent_id', count: 1, data: {peer: 'test.ardo', versus: :in})
      aggregate_class.create!(day: Time.now.strftime('%Y%m%d'), type: :skype, aid: 'agent_id', count: 2, data: {peer: 'test.one', versus: :in})
      aggregate_class.create!(day: Time.now.strftime('%Y%m%d'), type: :call, aid: 'agent_id', count: 3, data: {peer: 'test.ardissimo', versus: :in})
      entity.add_photo File.read(fixtures_path('image.001.jpg'))
      entity
    end

    let(:alice) do
      target = Item.create! name: "alice", _kind: :target, path: [operation.id], stat: ::Stat.new
      Entity.any_in({path: [target.id]}).first
    end

    # Prevent Eventmachine from deferring the execution
    # of the #run method
    before { EM.stub(:defer) { |block| block.call } }

    # Create some entities
    before { bob; alice }

    def subject params
      described_class.new :entity, 'export name', params
    end

    describe '#run' do

      let(:task) { subject(id: bob.id) }

      it 'does not raise any errors' do
        expect { task.run }.not_to raise_error
      end
    end

    describe '#total' do

      let(:task) { subject(id: bob.id) }

      it 'reurn the number of the entities + 1 + the number of photos' do
        expect(task.total).to eql task.entities.size + 1 + 1
      end
    end

    describe '#entities' do

      context 'when the "id" param is present' do

        let(:task) { subject(id: bob.id) }

        it 'returns an array with the entity fetched by the given id' do
          expect(task.entities.size).to eql 1
          expect(task.entities.first).to eql bob
        end
      end

      context 'when the "id" param is not present' do

        let(:task) { subject({}) }

        it 'returns an array with all the entities in the db' do
          expect(task.entities.size).to eql 2
        end
      end
    end
  end

end
end
