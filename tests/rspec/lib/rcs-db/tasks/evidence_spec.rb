#encoding: utf-8

require 'spec_helper'
require_db 'grid'
require_db 'db_layer'
require_db 'tasks'

module RCS
module DB

  describe EvidenceTask do

    silence_alerts
    enable_license
    stub_temp_folder

    # Prevent Eventmachine from deferring the execution of the #run method
    before do
      EM.stub(:defer) { |block| block.call }
    end

    let!(:target) { factory_create(:target, name: 'bob') }

    let!(:agent) { factory_create(:agent, target: target) }

    # Creates some evidences
    before do
      factory_create(:evidence, agent: agent, target: target, type: 'sms', data: {from: 'a', to: 'b', content: 'ciao', incoming: 1})
      factory_create(:screenshot_evidence, agent: agent, target: target, data: {program: 'viewer'})
      factory_create(:mic_evidence, agent: agent, target: target)
    end

    def subject filter
      described_class.new :evidence, 'my_evidences', {'filter' => filter, 'note' => true}
    end

    # TODO: the logic in this method can be used to extract the generated .tgz file
    # and test the validity of the content
    def run_and_open_archive task
      task.run

      # extract and open the generated .tgz file
      archive_path = RCS::DB::Config.instance.temp(task.instance_variable_get '@_id')
      archive_path_with_ext = "#{archive_path}.tgz"
      `mv "#{archive_path}" "#{archive_path_with_ext}"`
      `cd "#{File.dirname(archive_path_with_ext)}" && tar -zxvf #{archive_path_with_ext}`
      `open "#{File.dirname(archive_path_with_ext)}/index.html"`
    end

    describe '#run' do

      let(:task) do
        filter = {"from"=>1244190420, "to"=>1577833200, "blo"=>[false], "rel"=>[0, 1, 2, 3, 4], "date"=>"da", "target"=>target.id, "agent"=>agent.id}
        subject(filter)
      end

      it 'does not raise any errors' do
        pending
        # run_and_open_archive task
        # expect { task.run }.not_to raise_error
      end
    end
  end

end
end
