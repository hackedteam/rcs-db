require 'spec_helper'
require_db 'db_layer'
require_db 'grid'
require_db 'archive_node'

module RCS
  module DB
    describe ArchiveNode do

      silence_alerts
      enable_license

      let!(:signature) { Signature.create!(scope: 'network', value: 'nq8VzLWNtfyEnqORyEa6dR4PUXGlo6oU') }

      let(:address) { '127.0.0.1":4449' }

      let(:operation) { factory_create(:operation) }

      # let(:connector) { factory_create(:connector, item: operation, type: 'archive', dest: '127.0.0.1:4449') }

      let(:subject) { described_class.new(address) }

      describe '#sginature' do

        it 'returns the network signature' do
          expect(subject.signature).to eq(signature.value)
        end

        context 'when the signature is missing' do

          before { signature.destroy }

          it 'returns nil' do
            expect(subject.signature).to be_nil
          end
        end
      end

      describe 'status' do

        context 'when the status has been created' do

          let!(:status) { Status.create!(address: address, type: 'archive') }

          it 'returns the status of the node' do
            expect(subject.status).to eq(status)
          end
        end

        context 'when there status is missing' do

          it 'returns nil' do
            expect(subject.status).to be_nil
          end
        end
      end

      describe '#setup' do

        context 'when the response is 200 ok' do
          before do
            expect(subject.status).to be_nil
            subject.stub(:request).and_yield(200, nil)
          end

          it 'creates a status' do
            subject.setup!
            expect(subject.status).not_to be_nil
          end

          context 'when executed twice' do

            before do
              subject.setup!
              @updated_at = subject.status.reload.updated_at
              # TODO: remove sleep and stup updated_at value
              sleep 1.1
              subject.setup!
            end

            it 'updates the stasus' do
              expect(subject.status.updated_at).to be > @updated_at
            end
          end
        end

        context 'when the response is not 200 ok' do
          before do
            expect(subject.status).to be_nil
            subject.stub(:request).and_yield(500, {msg: 'foobar'})
          end

          it 'updates the status (to error)' do
            subject.setup!
            expect(subject.status.status).to eq(::Status::ERROR)
          end
        end
      end
    end
  end
end
