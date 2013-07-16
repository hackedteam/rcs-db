require 'spec_helper'
require_db 'db_layer'
require_db 'grid'
require_db 'sessions'
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

        before { subject.stub(:loop_on).and_yield }
        before { subject.stub(:wait_a_moment) }

        it 'calls #dispatcher' do
          subject.should_receive(:dispatch_or_wait)
          subject.dispatcher_start
        end

        context 'when #dispatcher raises an error' do

          before do
            turn_off_tracer(print_errors: false, raise_errors: false)

            subject.stub(:dispatch_or_wait) do
              $COUNT ||= 1
              $COUNT += 1
              raise "ooops" if $COUNT < 3
            end
          end

          it 'recalls it until it does not fail anymore' do
            subject.should_receive(:dispatch_or_wait).twice
            subject.dispatcher_start
          end
        end
      end

      describe '#pop' do

        context 'when there is nothing in the push_queue' do

          it('returns nil') { expect(subject.pop).to be_nil }
        end

        context 'when there is something in the push_queue' do

          before do
            2.times { |i| factory_create(:push_queue, type: "type#{i}", message: {num: i}) }
          end

          it 'returns its type and message' do
            expect(subject.pop).to eql ["type0", {'num' => 0}]
          end
        end
      end

      describe '#dispatch_or_wait' do

        context 'when there is something to dispatch' do
          before { factory_create(:push_queue, type: "type", message: {}) }

          it 'dispatches the available push queue' do
            subject.should_not_receive(:wait_a_moment)
            subject.should_receive(:dispatch).with("type", {})
            subject.dispatch_or_wait
          end
        end

        context 'when there is nothing to dispatch' do

          it 'waits' do
            subject.should_receive(:wait_a_moment)
            subject.should_not_receive(:dispatch)
            subject.dispatch_or_wait
          end
        end
      end

      describe '#each_session_with_web_socket' do

        let(:web_socket) { mock() }

        let!(:user0) { factory_create(:user) }
        let!(:user1) { factory_create(:user) }
        let!(:user2) { factory_create(:user) }

        context 'when two users are online' do

          before { WebSocketManager.instance.stub(:get_ws_from_cookie).and_return(web_socket) }

          let!(:session0) { factory_create(:session, user: user0) }

          let!(:session1) { factory_create(:session, user: user0) }

          it 'yields with the expectd paramenters' do
            expect { |b| subject.each_session_with_web_socket(&b) }.to  yield_successive_args([session0, web_socket], [session1, web_socket])
          end
        end

        context 'when there aren\'t online users' do

          it 'does not yield' do
            expect { |b| subject.each_session_with_web_socket(&b) }.not_to yield_with_args
          end
        end

        context 'when a user in online (without websocket)' do

          before { factory_create(:session, user: user0) }

          it 'does not yield' do
            expect { |b| subject.each_session_with_web_socket(&b) }.not_to yield_with_args
          end
        end
      end

      describe '#dispatch' do

        let(:web_socket) { mock() }

        let!(:user) { factory_create(:user) }

        let!(:session) { factory_create(:session, user: user) }

        before { subject.stub(:each_session_with_web_socket).and_yield(session, web_socket) }

        context 'when the message contains a recipient' do

          it 'sends the message only to that user (one)' do
            subject.should_receive(:send)
            subject.dispatch("type", {'rcpt' => session.user.id})
          end

          it 'sends the message only to that user (none)' do
            subject.should_not_receive(:send)
            subject.dispatch("type", {'rcpt' => '5183d763c78783751d000119'})
          end
        end

        context 'when the message contains user_ids' do

          it 'sends the message only to the users (one) matching user_ids' do
            subject.should_receive(:send)
            subject.dispatch("type", {'user_ids' => [user.id]})
          end

          it 'sends the message only to the users (none) matching user_ids' do
            subject.should_not_receive(:send)
            subject.dispatch("type", {'user_ids' => []})
          end
        end
      end
    end
  end
end
