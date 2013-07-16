require 'spec_helper'
require_db 'db_layer'
require_db 'grid'
require_db 'push'

module RCS
  module DB
    describe PushManager do

      enable_license
      silence_alerts

      let(:subject) { described_class.instance }

      before { subject.stub(:defer).and_yield }

      it 'uses the tracer module' do
        expect(subject).to respond_to(:trace)
      end

      describe '#notify' do

        before { PushQueue.stub(:add) }

        it 'logs the call' do
          subject.should_receive(:trace)
          subject.notify('type')
        end

        it 'creates a document in the push_queue' do
          PushQueue.should_receive(:add).with('type', {a: 1})
          subject.notify('type', {a: 1})
        end

        context 'when the message contains an item key' do

          let(:user) { factory_create(:user) }

          let(:item) { factory_create(:target, user_ids: [user.id]) }

          let(:message) { {item: item, b: 1} }

          it 'adds to the messeage its id and its user_ids (and remove item)' do
            PushQueue.should_receive(:add).with('type', {id: item.id, user_ids: item.user_ids, b: 1})
            subject.notify('type', message)
          end
        end
      end

      describe 'dispatcher_start' do

        it 'calls #dispatcher' do
          subject.should_receive(:dispatcher)
          subject.dispatcher_start
        end

        context 'when #dispatcher raises an error' do

          before do
            turn_off_tracer(print_errors: false, raise_errors: false)

            subject.stub(:dispatcher) do
              $COUNT ||= 1
              $COUNT += 1
              raise "ooops" if $COUNT < 3
            end
          end

          it 'recalls it until it does not fail anymore' do
            subject.should_receive(:dispatcher).twice
            subject.dispatcher_start
          end

        end
      end
    end
  end
end
