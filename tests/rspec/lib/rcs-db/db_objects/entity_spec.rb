require 'spec_helper'
require_db 'db_layer'
require_db 'link_manager'
require_db 'grid'
require_db 'position/resolver'

describe Entity do

  silence_alerts
  enable_license

  describe 'relations' do
  	it 'should embeds many Handles' do
      subject.should respond_to :handles
    end

    it 'should embeds many Links' do
       subject.should respond_to :links
    end

    it 'should belongs to many Users' do
      subject.should respond_to :users
    end
  end


  describe '#with_handle' do

    context "given an entity with two handles" do

      let!(:entity) { factory_create(:target_entity) }

      before do
        factory_create :entity_handle, entity: entity, type: 'skype', handle: 'g.lucas'
        factory_create :entity_handle, entity: entity, type: 'phone', handle: '342 1232981'
        factory_create :entity_handle, entity: entity, type: 'phone', handle: '00393991242999'
        factory_create :entity_handle, entity: entity, type: 'phone', handle: '393699801223'
      end

      it 'finds the entity that matches the given handle\'s type and value' do
        expect(described_class.with_handle('skype', 'g.lucas').count).to eql 1
        expect(described_class.with_handle('skype', '342 1232981').count).to eql 0
        expect(described_class.with_handle('phone', '3421232981').count).to eql 1
        expect(described_class.with_handle('phone', '342-1232981').count).to eql 1
        expect(described_class.with_handle('phone', '+1111 342-1232981').count).to eql 0
        expect(described_class.with_handle('phone', '+39 342 1232981').count).to eql 1
        expect(described_class.with_handle('phone', '001 342 1232981').count).to eql 1
        expect(described_class.with_handle('phone', '+39 399-1242999').count).to eql 1
        expect(described_class.with_handle('phone', '3421232981').count).to eql 1
        expect(described_class.with_handle('phone', '421232981').count).to eql 0
        expect(described_class.with_handle('phone', '981').count).to eql 0
        expect(described_class.with_handle('phone', '981').count).to eql 0
      end
    end
  end

  context 'creating a new target' do

    it 'should create a new entity' do
      target = Item.create!(name: 'test-target', _kind: 'target', path: [], stat: ::Stat.new)

      entity = Entity.where(name: 'test-target').first
      entity.should_not be_nil
      entity.path.should eq target.path + [target._id]
    end

  end

  context 'creating a new entity' do
    it 'should alert and notify via push' do
      Entity.any_instance.should_receive(:alert_new_entity)
      Entity.any_instance.should_receive(:push_new_entity)

      operation = Item.create!(name: 'test-operation', _kind: 'operation', path: [], stat: ::Stat.new)
      Entity.create!(name: 'test-entity', type: :person, path: [operation._id])
    end
  end

  context 'modifying an entity' do
    before do
      @operation = Item.create!(name: 'test-operation', _kind: 'operation', path: [], stat: ::Stat.new)
      @entity = Entity.create!(name: 'test-entity', type: :person, path: [@operation._id])
    end

    it 'should notify name modification' do
      Entity.any_instance.should_receive(:push_modify_entity)

      @entity.name = 'test-modified'
      @entity.save
    end

    it 'should notify desc modification' do
      Entity.any_instance.should_receive(:push_modify_entity)

      @entity.desc = 'test-modified'
      @entity.save
    end

    it 'should notify position modification' do
      Entity.any_instance.should_receive(:push_modify_entity)

      @entity.last_position = {longitude: 45, latitude: 9, accuracy: 500, time: Time.now.to_i}
      @entity.save
    end

    it 'should assing and return last position correctly' do
      @entity.last_position = {longitude: 45, latitude: 9, accuracy: 500, time: Time.now.to_i}
      @entity.last_position[:longitude].should eq 45.0
      @entity.last_position[:latitude].should eq 9.0
      @entity.last_position[:accuracy].should eq 500
    end

    before { turn_off_tracer(print_errors: false) }

    it 'should add and remove photos to/from grid' do
      @entity.add_photo("This_is_a_binary_photo")
      photo_id = @entity.photos.first
      photo_id.should be_a String

      @entity.del_photo(photo_id)
      expect { RCS::DB::GridFS.get(photo_id, @entity.path.last.to_s) }.to raise_error(Mongo::GridFileNotFound)
    end

  end

  context 'destroying an entity' do
    before do
      @operation = Item.create!(name: 'test-operation', _kind: 'operation', path: [], stat: ::Stat.new)
      @entity = Entity.create!(name: 'test-entity', type: :person, path: [@operation._id])
    end

    it 'should notify via push' do
      Entity.any_instance.should_receive(:push_destroy_entity)

      @entity.destroy
    end

    it 'should destroy all links' do
      entity2 = Entity.create!(name: 'test-entity-two', type: :person, path: [@operation._id])

      RCS::DB::LinkManager.instance.add_link(from: @entity, to: entity2, level: :manual, type: :peer)

      entity2.links.size.should be 1

      @entity.destroy

      entity2.reload
      entity2.links.size.should be 0
    end

    before { turn_off_tracer(print_errors: false) }

    it 'should remove photos in the grid' do
      @entity.add_photo("This_is_a_binary_photo")
      photo_id = @entity.photos.first
      @entity.destroy
      expect { RCS::DB::GridFS.get(photo_id, @entity.path.last.to_s) }.to raise_error(Mongo::GridFileNotFound)
    end
  end

  describe '#move_links' do

    let(:operation) { factory_create :operation }
    let(:target_a) { factory_create :target, operation: operation }
    let(:target_b) { factory_create :target, operation: operation }
    let(:target_entity_a) { factory_create :target_entity, target: target_a }
    let(:target_entity_b) { factory_create :target_entity, target: target_b }
    let(:person_entity_c) { factory_create :person_entity, operation: operation }
    let(:person_entity_d) { factory_create :person_entity, operation: operation }

    before do
      RCS::DB::LinkManager.instance.add_link(from: person_entity_c, to: person_entity_d, level: :automatic, type: :identity)
      RCS::DB::LinkManager.instance.add_link(from: person_entity_c, to: target_entity_a, level: :automatic, type: :peer, info: ["x"])
      RCS::DB::LinkManager.instance.add_link(from: person_entity_d, to: target_entity_a, level: :automatic, type: :peer, info: ["y"])
      RCS::DB::LinkManager.instance.add_link(from: person_entity_d, to: target_entity_b, level: :automatic, type: :peer, info: ["z"])
    end

    it 'preserves the value of the info array' do
      person_entity_d.merge person_entity_c

      links_from_d_to_a = person_entity_d.reload.links.connected_to(target_entity_a)
      expect(links_from_d_to_a.count).to eql 1
      expect(links_from_d_to_a.first.info).to eql %w[y x]

      links_from_d_to_b = person_entity_d.reload.links.connected_to(target_entity_b)
      expect(links_from_d_to_b.count).to eql 1
      expect(links_from_d_to_b.first.info).to eql %w[z]
    end
  end

  context 'merging two entities' do
    before do
      Entity.any_instance.stub :link_target_entities_passed_from_here

      @operation = Item.create!(name: 'test-operation', _kind: 'operation', path: [], stat: ::Stat.new)
      @first_entity = Entity.create!(name: 'entity-1', type: :target, path: [@operation._id], level: :automatic)
      @second_entity = Entity.create!(name: 'entity-2', type: :person, path: [@operation._id], level: :automatic)
      @third_entity = Entity.create!(name: 'entity-3', type: :person, path: [@operation._id], level: :automatic)
      @position_entity = Entity.create!(name: 'entity-position', type: :position, path: [@operation._id])
    end

    it 'should not merge incompatible entities' do
      expect { @first_entity.merge(@position_entity) }.to raise_error
      expect { @second_entity.merge(@first_entity) }.to raise_error
      expect { @position_entity.merge(@second_entity) }.to raise_error
    end

    it 'should merge handles' do
      @first_entity.handles.create!(level: :manual, type: 'skype', name: 'Test Name', handle: 'test.name')
      @second_entity.handles.create!(level: :manual, type: 'gmail', name: 'Test Name', handle: 'test.name@gmail.com')

      @first_entity.merge @second_entity

      @first_entity.handles.size.should be 2
      @first_entity.handles.last[:handle].should eq 'test.name@gmail.com'
    end

    it 'should be set to manual' do
      @first_entity.merge @second_entity
      @first_entity.level.should be :manual
    end

    it 'should merge links' do
      # lets create this scenario (links as follow):
      # 1 -> 2 (identity)
      # 2 -> 3 (peer)
      # 2 -> 4 (position)
      # we will merge 1 and 2 and it should result in:
      # 1 -> 3 (peer)
      # 1 -> 4 (position)
      RCS::DB::LinkManager.instance.add_link(from: @first_entity, to: @second_entity, level: :manual, type: :identity, info: ["a"])
      RCS::DB::LinkManager.instance.add_link(from: @second_entity, to: @third_entity, level: :manual, type: :peer, info: ["b"])
      RCS::DB::LinkManager.instance.add_link(from: @second_entity, to: @position_entity, level: :manual, type: :position, info: ["c"])

      @first_entity.merge @second_entity
      @first_entity.reload
      @third_entity.reload
      @position_entity.reload
      expect { @second_entity.reload }.to raise_error

      # total link count
      @first_entity.links.size.should be 2

      # check if the links point to the right entities
      @first_entity.links.connected_to(@third_entity).count.should be 1
      @first_entity.links.connected_to(@position_entity).count.should be 1

      # check the backlinks
      @third_entity.links.size.should be 1
      @third_entity.links.first.linked_entity.should == @first_entity

      @position_entity.links.size.should be 1
      @position_entity.links.first.linked_entity.should == @first_entity
    end
  end

  context 'searching for peer' do
    before do
      @target = Item.create!(name: 'test-target', _kind: 'target', path: [], stat: ::Stat.new)
      @entity = Entity.any_in({path: [@target._id]}).first
    end

    it 'should find peer versus' do
      Aggregate.target(@target._id).create!(type: 'sms', day: Time.now.strftime('%Y%m%d'), aid: "agent_id", count: 1, data: {peer: 'test', versus: :in})
      versus = @entity.peer_versus EntityHandle.new(type: 'sms', handle: 'test')
      versus.should be_a Array
      versus.should include :in

      Aggregate.target(@target._id).create!(type: 'sms', day: Time.now.strftime('%Y%m%d'), aid: "agent_id", count: 1, data: {peer: 'test', versus: :out})
      versus = @entity.peer_versus EntityHandle.new(type: 'sms', handle: 'test')
      versus.should be_a Array
      versus.should include :out

      versus.should eq [:in, :out]
    end

    context 'when the handle type is not directly mapped to the aggregate type' do

      # Creates an aggregate (type is SMS)
      let!(:sms_aggregate) do
        aggregate_params = {type: 'sms', data: {peer: '+1555129', versus: :in}, day: Time.now.strftime('%Y%m%d'), aid: "agent_id", count: 1}
        Aggregate.target(@target._id).create! aggregate_params
      end

      it 'finds the peer versus' do
        versus = @entity.peer_versus EntityHandle.new(type: 'phone', handle: '+1555129')
        expect(versus).not_to be_empty
      end
    end

    context 'with intelligence enabled' do

      it 'should return name from handle (from entities)' do
        @entity.handles.create!(type: 'phone', handle: '123')

        name = Entity.name_from_handle('sms', '123', @target._id.to_s)

        name.should eq @target.name
      end
    end

    context 'with intelligence disabled' do
      before do
        Entity.stub(:check_intelligence_license).and_return false
        turn_off_tracer(print_errors: false)
      end

      it 'should return name from handle (from addressbook)' do
        agent = Item.create(name: 'test-agent', _kind: 'agent', path: [@target._id], stat: ::Stat.new)
        Evidence.target(@target._id.to_s).create!(da: Time.now.to_i, aid: agent._id, type: 'addressbook', data: {name: 'test-addressbook', handle: 'test-a'}, kw: ['phone', 'test', 'a'])

        name = Entity.name_from_handle('sms', 'test-a', @target._id.to_s)

        name.should eq 'test-addressbook'
      end
    end
  end

  context 'given a ghost entity' do
    before do
      @operation = Item.create!(name: 'test-operation', _kind: 'operation', path: [], stat: ::Stat.new)
      @first_entity = Entity.create!(name: 'entity-1', type: :target, path: [@operation._id], level: :automatic)
      @second_entity = Entity.create!(name: 'entity-2', type: :person, path: [@operation._id], level: :automatic)

      @ghost = Entity.create!(name: 'ghost', level: :ghost, type: :person, path: [@operation._id])
    end

    it 'should not be promoted to automatic with one link only' do
      @ghost.level.should be :ghost
      RCS::DB::LinkManager.instance.add_link(from: @first_entity, to: @ghost, level: :ghost, type: :know, versus: :out)
      @ghost.level.should be :ghost
    end

    it 'should be promoted to automatic with at least two link' do
      RCS::DB::LinkManager.instance.add_link(from: @first_entity, to: @ghost, level: :ghost, type: :know, versus: :out)
      RCS::DB::LinkManager.instance.add_link(from: @second_entity, to: @ghost, level: :ghost, type: :know, versus: :out)

      @ghost.level.should be :automatic

      @ghost.links.each do |link|
        link.level.should be :automatic
      end
    end
  end

  context 'creating a new handle' do
    before do
      @operation = Item.create!(name: 'test-operation', _kind: 'operation', path: [], stat: ::Stat.new)
      @entity = Entity.create!(name: 'entity', type: :target, path: [@operation._id], level: :automatic)
      @identity = Entity.create!(name: 'entity-same', type: :person, path: [@operation._id], level: :automatic)
    end

    it 'should check for identity with other entities' do
      @entity.handles.create!(type: 'phone', handle: '123')

      @entity.links.size.should be 0
      @identity.links.size.should be 0

      @identity.handles.create!(type: 'phone', handle: '123')
      @entity.reload
      @identity.reload

      @entity.links.size.should be 1
      @identity.links.size.should be 1

      @entity.links.first[:le].should eq @identity._id
    end
  end

end

describe EntityLink do

  silence_alerts
  enable_license

  describe '#connected_to' do

    let (:operation) { Item.create!(name: 'test-operation', _kind: 'operation', path: [], stat: ::Stat.new) }

    let (:first_entity) { Entity.create! path: [operation.id] }

    let (:second_entity) { Entity.create! path: [operation.id] }

    it 'is a mongoid scope' do
      first_entity.links.connected_to(second_entity).kind_of?(Mongoid::Criteria).should be_true
    end

    context 'when there is a link' do

      before { RCS::DB::LinkManager.instance.add_link from: first_entity, to: second_entity }

      it 'returns the entities connected with the given one' do
        first_entity.links.connected_to(second_entity).count.should == 1
      end
    end

    context 'when there are no links' do

      it 'returns nothing' do
        first_entity.links.connected_to(second_entity).count.should be_zero
      end
    end
  end

  context 'setting parameters' do
    it 'should not duplicate info' do
      subject.add_info "a"
      subject.add_info "b"
      subject.add_info "a"
      subject.add_info ["a", "b", "x"]
      subject.info.size.should be 3
      subject.info.should eq ['a', 'b', 'x']
    end

    context 'when versus is not set' do
      it 'should set versus if the first time' do
        subject.set_versus :in
        subject.versus.should be :in
      end
    end

    context 'when versus is already set' do
      before do
        subject.set_versus :in
      end

      it 'should not change versus' do
        subject.set_versus :in
        subject.versus.should be :in
      end

      it 'should upgrade to :both if different' do
        subject.set_versus :out
        subject.versus.should be :both
      end
    end

    it 'should upgrade type from :know to :peer' do
      subject.set_type :know
      subject.set_type :peer
      subject.type.should be :peer
    end

    it 'should not overwrite type with :know' do
      subject.set_type :peer
      subject.set_type :know
      subject.type.should be :peer
      subject.set_type :identity
      subject.set_type :know
      subject.type.should be :identity
    end

    it 'should upgrade level from :ghost to :automatic' do
      subject.set_level :ghost
      subject.set_level :automatic
      subject.level.should be :automatic
    end

    it 'should not overwrite level with :ghost' do
      subject.set_level :automatic
      subject.set_level :ghost
      subject.level.should be :automatic
      subject.set_level :manual
      subject.set_level :ghost
      subject.level.should be :manual
    end

    context 'deleting a ghost link' do
      before do
        @operation = Item.create!(name: 'test-operation', _kind: 'operation', path: [], stat: ::Stat.new)
        @entity = Entity.create!(name: 'entity', type: :target, path: [@operation._id], level: :automatic)
        @ghost = Entity.create!(name: 'ghost', type: :person, path: [@operation._id], level: :ghost)

        RCS::DB::LinkManager.instance.add_link(from: @entity, to: @ghost, level: :ghost, type: :know)
      end

      it 'should delete the linked ghost entity' do
        RCS::DB::LinkManager.instance.del_link(from: @entity, to: @ghost)
        expect { Entity.find(@ghost._id) }.to raise_error Mongoid::Errors::DocumentNotFound
      end

      it 'should not delete the entity if not ghost' do
        @ghost.level = :automatic
        @ghost.save
        RCS::DB::LinkManager.instance.del_link(from: @entity, to: @ghost)
        Entity.find(@ghost._id).should eq @ghost
      end
    end

    describe 'Create callbacks' do

      def create_position_entity params
        params[:level] ||= :automatic
        entity_params = params.merge name: "Postion #{params[:position]}", path: [operation.id], type: :position
        Entity.create! entity_params
      end

      before { Entity.create_indexes }

      let(:operation) { Item.create!(name: 'op', _kind: 'operation', path: [], stat: ::Stat.new) }

      context 'Given a position entity' do

        let(:position_entity) { create_position_entity position: [-74.04449, 40.68944] }

        before { position_entity }

        context 'When an user creates a position entity for a place closer to the given one' do

          let(:another_position_entity) { create_position_entity position: [-74.04448, 40.68945], level: :manual }

          it 'creates an "identity" link between the two' do
            expect(another_position_entity.linked_to?(position_entity.reload, type: :identity)).to be_true
          end
        end

        # @note: This case should never be happen in production
        context 'When the system creates a position entity for a place closer to the given one' do

          let(:another_position_entity) { create_position_entity position: [-74.04448, 40.68945], level: :automatic }

          it 'does not creates any link between the two' do
            expect(another_position_entity.linked_to? position_entity.reload).to be_false
          end
        end

        context 'When an user creates a position entity for a place far from the given one' do

          let(:another_position_entity) { create_position_entity position: [-74.05128, 40.72835], level: :manual }

          it 'does not creates any link between the two' do
            expect(another_position_entity.linked_to? position_entity.reload).to be_false
          end
        end
      end

      context 'Given a target entity' do

        let!(:now) { Time.at(Time.now.to_i) }

        let(:target_entity) do
          Item.create! name: 'bob', _kind: 'target', path: [operation.id], stat: ::Stat.new
          Entity.where(name: 'bob').first
        end

        context 'That have been to the Statue of Liberty' do


          let(:timeframes) { [{'start' => now, 'end' => now}, {'start' => now+1, 'end' => now+1}] }

          before do
            data = {'position' => [-74.04448, 40.68945], 'radius' => 2}
            aggregate_params = {type: :position, info: timeframes, data: data, aid: 'agent_id', count: 1, day: '20130301'}
            Aggregate.target(target_entity.target_id).create! aggregate_params
          end

          context 'When a position entity for a place closer to the Statue of Liberty is created by a user' do

            let(:position_entity) { create_position_entity position: [-74.04449, 40.68944], level: :manual }

            it 'creates a valid "position" link between the two entities' do
              expect(position_entity.linked_to?(target_entity.reload, type: :position)).to be_true

              link = position_entity.links.connected_to(target_entity).first
              expect(link.info).to eql timeframes
            end
          end

          context 'When a position entity for a place closer to the Statue of Liberty is created by the system' do

            let(:position_entity) { create_position_entity position: [-74.04449, 40.68944], level: :automatic }

            it 'creates a "position" link between the two entities' do
              expect(position_entity.linked_to?(target_entity.reload, type: :position)).to be_true
            end
          end

          context 'When a position entity for a place far from the Statue of Liberty is created' do

            let(:position_entity) { create_position_entity position: [-74.05128, 40.72835] }

            it 'does not creates any link between the two' do
              expect(position_entity.linked_to? target_entity.reload).to be_false
            end
          end
        end
      end
    end

    describe '#fetch_address' do

      let(:operation) { Item.create!(name: 'op', _kind: 'operation', path: [], stat: ::Stat.new) }

      def create_position_entity params
        params[:level] ||= :automatic
        entity_params = params.merge name: "Postion #{params[:position]}", path: [operation.id], type: :position
        Entity.create! entity_params
      end

      let(:position_entity) { create_position_entity position: [-74.04449, 40.68944] }

      let(:expected_address) { "1 Liberty Island - Ellis Island, Liberty Island, New York, NY 10004, USA" }

      before { RCS::DB::PositionResolver.stub(:get).and_return "address" => {"text" => expected_address} }

      it 'fetch the correct address name from a web service' do
        expect { position_entity.fetch_address}.to change(position_entity, :name).to(expected_address)
      end
    end
  end
end
