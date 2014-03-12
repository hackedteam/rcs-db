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
          expect(db.name).to eq(DB::WORKER_DB_NAME)
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

        let!(:target) { factory_create :target }

        let!(:agent) { factory_create :agent, target: target, ident: 'foo', instance: 'bar', status: 'open', logkey: 'foo bar key' }

        let!(:raw_evidence) { factory_create(:raw_evidence, agent: agent, content: 'foo') }

        let!(:raw_evidence2) { factory_create(:raw_evidence, agent: agent, content: 'bar') }

        let!(:subject) { described_class.new(agent.instance, agent.ident) }


        describe '#process' do

          before do
            ev = {type: :message, data: {'from' => 'me', 'to' => 'you'}}
            subject.stub(:decrypt_evidence).and_return([[ev], 'decoded_content'])
          end

          it 'runs without errors' do
            subject.fetch.each { |ev| subject.process(ev) }
          end

          context 'when a memory error is raised' do

            before do
              subject.stub(:decrypt_evidence).and_raise(NoMemoryError.new("foo memory"))
            end

            it 'raises that error' do
              expect { subject.fetch.each { |ev| subject.process(ev) } }.to raise_error(NoMemoryError)
            end

            it 'keeps the raw evidence' do
              begin
                subject.fetch.each { |ev| subject.process(ev) }
              rescue Exception
              end

              expect(subject.fetch.count).to eq(2)
            end
          end


          context 'when a general error is raised' do

            before do
              subject.stub(:decrypt_evidence).and_raise(Exception.new("foo error"))
              subject.stub(:trace)
            end

            it 'does not raise that error' do
              expect { subject.fetch.each { |ev| subject.process(ev) } }.not_to raise_error
            end

            it 'deletes the raw evidence' do
              subject.fetch.each { |ev| subject.process(ev) }
              expect(subject.fetch.count).to eq(0)
            end
          end
        end

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
