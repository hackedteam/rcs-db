require 'spec_helper'
require_db 'db_layer'
require_db 'grid'

module RCS
  module DB
    describe DB do

      enable_license

      let(:subject) { described_class.instance }

      context 'when the license archive is enabled' do

        before do
          LicenseManager.instance.should_receive(:check).with(:archive).and_return(true)
        end

        describe '#archive_mode?' do

          it('returns true') { expect(subject.archive_mode?).to be_true }
        end

        describe '#ensure_signatures' do

          before { subject.stub(:dump_network_signature) }

          it 'creates the signatures' do
            subject.ensure_signatures
            expect(Signature.count).to be_zero
          end
        end
      end

      context 'when the license archive is not enabled' do

        before do
          LicenseManager.instance.should_receive(:check).with(:archive).and_return(false)
        end

        describe '#archive_mode?' do

          it('returns false') { expect(subject.archive_mode?).to be_false }
        end

        describe '#ensure_signatures' do

          before { subject.stub(:dump_network_signature) }

          it 'does not create any signatures' do
            Signature.should_receive(:create).exactly(4).times
            subject.ensure_signatures
          end
        end
      end
    end
  end
end
