#encoding: utf-8

require 'spec_helper'
require_db 'grid'
require_db 'db_layer'
require_db 'tasks'

module RCS
module DB

  describe EntityTask do

    silence_alerts
    enable_license
    stub_temp_folder

    let(:admin) { factory_create(:user, name: 'admin', enabled: true) }

    let(:operation) do
      Item.create!(name: 'Op LoL', _kind: :operation, path: [], stat: ::Stat.new).tap do |op|
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
    end

    # Create some entities
    before { bob; alice; sagrada_familia }

    def subject params
      described_class.new :entity, 'export name', params.merge(operation: operation.id).stringify_keys
    end

    # TODO: the logic in this method can be used to extract the generated .tgz file
    # and test the validity of the content
    # def run_and_open_archive task
    #   # create export.zip
    #   src = Config.instance.file 'export.zip.src'
    #   dest = Config.instance.file 'export.zip'
    #   `cd "#{src}" && 7z a style.zip style/*`
    #   `mv "#{src}/style.zip" "#{dest}"`

    #   task.run

    #   # extract and open the generated .tgz file
    #   archive_path = RCS::DB::Config.instance.temp(task.instance_variable_get '@_id')
    #   archive_path_with_ext = "#{archive_path}.tgz"
    #   `mv "#{archive_path}" "#{archive_path_with_ext}"`
    #   `cd "#{File.dirname(archive_path_with_ext)}" && tar -zxvf #{archive_path_with_ext}`
    #   `open "#{File.dirname(archive_path_with_ext)}/index.html"`
    # end

    describe '#run' do

      let(:task) { subject({}) }

      it 'does not raise any errors' do
        # run_and_open_archive task
        expect { task.run }.not_to raise_error
      end
    end

    describe '#total' do

      let(:task) { subject(id: [bob.id]) }

      it 'reurn the number of the entities + 1 + the number of photos + the number of files in "export.zip"' do
        expect(task.total).to eql task.entities.size + 1 + 2 + FileTask.style_assets_count
      end
    end

    describe '#entities' do

      context 'when the "id" param is present' do

        let(:task) { subject(id: [bob.id]) }

        it 'returns an array with the entity fetched by the given ids' do
          expect(task.entities.size).to eql 1
          expect(task.entities.first).to eql bob
        end
      end

      context 'when the "id" param is not present' do

        let(:task) { subject({}) }

        it 'returns an array with all the entities in the db' do
          expect(task.entities.size).to eql 3
        end
      end
    end
  end

end
end
