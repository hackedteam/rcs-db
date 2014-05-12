require 'spec_helper'

require_db 'offload_manager'
require_db 'grid'
require_db 'db_layer'
require_db 'tasks'

module RCS
  module DB
    describe MoveagentTask do

      silence_alerts
      enable_license
      stub_temp_folder

      # Prevent Eventmachine from deferring the execution of the #run method
      before do
        EM.stub(:defer) { |block| block.call }
      end

      let(:user) { factory_create(:user) }

      let!(:src_target) { factory_create(:target) }

      let!(:src_agent) { factory_create(:agent, target: src_target) }

      let!(:dst_target) { factory_create(:target) }

      let!(:connector_on_src_agent) { factory_create(:connector, item: src_agent)}

      let!(:connector_on_dst_target) { factory_create(:connector, item: dst_target)}

      let!(:connector_on_src_target) { factory_create(:connector, item: src_target)}

      before do
        factory_create(:chat_evidence, target: src_target, agent: src_agent)
        @screenshot_evidence = factory_create(:screenshot_evidence, target: src_target, agent: src_agent)
      end

      # Initialize a MoveagentTask class that will move src_agent into dst_target.
      let(:subject) do
        params = {'_id' => src_agent.id, 'target' => dst_target.id, user: user}
        described_class.new(:moveagent, 'my_task', params)
      end

      it 'expect to move the agent to a target belonging to another op' do
        expect(src_target.path.first).not_to eq(dst_target.path.first)
      end

      describe '#total' do
        it 'returns the number of agent\'s evidence plus 2' do
          expect(subject.total).to eq(2 + 2)
        end
      end

      describe '#run' do

        before { subject.run }

        it 'updates the connectors\' paths defined on the moved agent' do
          old_path, new_path = connector_on_src_agent.path, connector_on_src_agent.reload.path
          expect(new_path).not_to eq(old_path)
          expect(new_path).to eq(dst_target.path << dst_target.id << src_agent.id)
        end

        it 'does not broke up other connectors\' paths' do
          expect(connector_on_src_target.path).to eq(connector_on_src_target.reload.path)
          expect(connector_on_dst_target.path).to eq(connector_on_dst_target.reload.path)
        end

        it 'does not broke up items\' paths' do
          expect(dst_target.path).to eq(dst_target.reload.path)
          expect(src_target.path).to eq(src_target.reload.path)
          expect(src_agent.reload.path).to eq(dst_target.path << dst_target.id)
        end

        before { [dst_target, src_agent, src_target].map(&:reload) }

        it 'moves the agent to another target' do
          expect(src_agent.get_parent).to eq(dst_target)
        end

        context 'evidence' do

          let(:moved_evidence) {  Evidence.target(dst_target).where(type: 'screenshot').first }

          let(:old_evidence) { @screenshot_evidence }

          it 'are moved too' do
            expect(Evidence.target(src_target).count).to be_zero
            aids = Evidence.target(dst_target).all.map(&:aid)
            expect(aids).to eq([src_agent.id.to_s, src_agent.id.to_s])
          end

          it 'changes their id' do
            expect { old_evidence.reload }.to raise_error
          end

          it 'do not lose their attachments' do
            expect(GridFS.get(old_evidence.data['_grid'], src_target.id)).to be_nil
            expect(GridFS.get(moved_evidence.data['_grid'], dst_target.id)).not_to be_nil
          end
        end
      end
    end
  end
end