require 'spec_helper'
require_worker 'instance_worker'

module RCS
  module Worker
    describe InstanceWorker do

      silence_alerts
      enable_license

      describe '#db' do
        it 'returns a database class that refers to the correct database' do
          db = described_class.new('foo', 'bar').db
          expect(db.instance_variable_get('@current_database').name).to eq(DB::WORKER_DB_NAME)
        end
      end

      context 'when the agent exists and it\'s open' do

        let(:agent) { factory_create(:agent, status: 'open') }

        let(:subject) { described_class.new(agent.instance, agent.ident) }

        describe '#agent' do

          it('returns it') { expect(subject.agent).to eq(agent) }

          it 'caches it upon multiple calls' do
            subject.agent
            Item.should_not_receive(:agents).and_call_original
            2.times { subject.agent }
          end
        end

        describe '#target' do

          it('returns its target') { expect(subject.target).to eq(agent.get_parent) }

          it 'caches it upon multiple calls' do
            subject.target
            Item.should_not_receive(:agents).and_call_original
            2.times { subject.target }
          end
        end

        describe '#angent?' do

          it('returns true') { expect(subject.agent?).to be_true }

          it 'clears the cache' do
            Item.should_receive(:agents).and_call_original
            subject.agent?
          end
        end
      end

      context 'when the agent exists and it\'s not open' do

        let(:agent) { factory_create(:agent, status: 'closed') }

        let(:subject) { described_class.new(agent.instance, agent.ident) }

        describe 'both #agent and #target' do

          it('return nil') do
            expect(subject.target).to be_nil
            expect(subject.agent).to be_nil
          end
        end
      end

      context 'when the agent is missing' do

        let(:subject) { described_class.new('foo', 'bar') }

        describe 'both #agent and #target' do

          it('return nil') do
            expect(subject.target).to be_nil
            expect(subject.agent).to be_nil
          end
        end
      end

      context 'given an agent with evidence to be processed' do
        let(:target) { factory_create :target }

        let(:agent) { factory_create :agent, target: target }

        let(:subject) { described_class.new(agent.instance, agent.ident) }

        let!(:raw_evidence) { factory_create(:raw_evidence, agent: agent, content: "hello") }

        let!(:raw_evidence2) { factory_create(:raw_evidence, agent: agent, content: "hello") }

        describe '#delete_all_evidence' do
          before do
            turn_off_tracer(print_errors: false)
            expect(subject.fetch.count).to eq(2)
          end

          it 'deletes all the evidence' do
            subject.delete_all_evidence
            expect(subject.fetch.count).to eq(0)
          end
        end
      end
    end
  end
end

# Remove the RCS::Evidence class defined by rcs-common/evidence
if defined? RCS::Evidence
  RCS.send :remove_const, 'Evidence'
end
