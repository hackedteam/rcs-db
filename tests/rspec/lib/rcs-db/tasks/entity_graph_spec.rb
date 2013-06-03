#encoding: utf-8

require 'spec_helper'
require_db 'grid'
require_db 'db_layer'
require_db 'tasks'

module RCS
module DB

  describe EntitygraphTask do

    use_db
    silence_alerts
    enable_license
    stub_temp_folder

    let(:admin) { User.create! name: 'admin', enabled: true }

    let(:operation) do
      Item.create!(name: 'Op LoL', _kind: :operation, path: [], stat: ::Stat.new).tap do |op|
        op.users << admin
      end
    end

    let(:bob) do
      target = Item.create! name: "bob", _kind: :target, path: [operation.id], stat: ::Stat.new
      entity = Entity.any_in({path: [target.id]}).first

      entity.add_photo File.read(fixtures_path('image.001.jpg'))
      entity.add_photo File.read(fixtures_path('image.001.jpg'))

      entity.position = [-73.04449, 46.68944]
      entity.position_attr = {'time' => Time.now.to_i, 'accuracy' => 10}

      entity.save
      entity
    end

    let(:alice) do
      target = Item.create! name: "alice", _kind: :target, path: [operation.id], stat: ::Stat.new
      Entity.any_in({path: [target.id]}).first
    end

    let(:sagrada_familia) do
      Entity.create! name: 'Sagrada Família, Barcellona', aid: 'agent_id', position: [2.17450, 41.40345], level: :manual, path: [operation.id], type: :position
    end

    before do
      # Prevent Eventmachine from deferring the execution
      # of the #run method
      EM.stub(:defer) { |block| block.call }

      # Build Entity indexes to enable geoNear search
      Entity.create_indexes

      # Create some entities
      bob
      alice
      sagrada_familia
      LinkManager.instance.add_link(from: alice, to: bob, type: :peer, versus: :both)
    end

    def subject params
      described_class.new :entity_graph, 'export name', params.merge(operation: operation.id).stringify_keys
    end

    # TODO: the logic in this method can be used to extract the generated .tgz file
    # and test the validity of the content
    # def run_and_open_archive task
    #   task.run

    #   # extract and open the generated .tgz file
    #   archive_path = RCS::DB::Config.instance.temp(task.instance_variable_get '@_id')
    #   archive_path_with_ext = "#{archive_path}.tgz"
    #   `mv "#{archive_path}" "#{archive_path_with_ext}"`
    #   `cd "#{File.dirname(archive_path_with_ext)}" && tar -zxvf #{archive_path_with_ext}`
    #   `subl "#{File.dirname(archive_path_with_ext)}/map.graphml"`
    # end

    describe '#entities' do

      it 'returns 2 entities when map_type is "link"' do
        task = subject(map_type: 'link')
        expect(task.entities.size).to eql 2
      end

      it 'returns 1 entity when map_type is "position"' do
        task = subject(map_type: 'position')
        expect(task.entities.size).to eql 1
      end

      it 'returns all the entities when map_type is invalid or missing' do
        task = subject({})
        expect(task.entities.size).to eql 3
      end
    end

    describe '#run' do

      let(:task) { subject({}) }

      it 'does not raise any errors' do
        expect { task.run }.not_to raise_error
      end
    end
  end

end
end
