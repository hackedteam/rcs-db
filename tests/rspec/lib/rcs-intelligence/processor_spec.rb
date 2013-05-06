require 'spec_helper'
require_db 'db_layer'
require_intelligence 'processor'

module RCS
module Intelligence

describe Processor do
  before do
    turn_off_tracer
    connect_mongoid
    empty_test_db
  end

  after { empty_test_db }


  it 'should use the Tracer module' do
    described_class.should respond_to :trace
  end


  describe '#run' do
    let(:queue_entry) { [:first_item, :second_item] }

    before { described_class.stub!(:sleep).and_return :sleeping }
    before { described_class.stub!(:loop).and_yield }

    context 'the IntelligenceQueue is not empty' do
      before { IntelligenceQueue.stub(:get_queued).and_return queue_entry }

      it 'should process the first entry' do
        described_class.should_receive(:process).with :first_item
        described_class.run
      end
    end

    context 'the IntelligenceQueue is empty' do
      before { IntelligenceQueue.stub(:get_queued).and_return nil }

      it 'should wait a second' do
        described_class.should_not_receive :process
        described_class.should_receive(:sleep).with 1
        described_class.run
      end
    end
  end


  describe '#process_evidence' do
    let(:evidence) { mock() }
    let(:entity) { mock() }

    context 'the type of the evidence is "addressbook"' do
      before { evidence.stub(:type).and_return 'addressbook' }
      before { Accounts.stub(:get_addressbook_handle).and_return nil }
      before { Accounts.stub(:add_handle).and_return nil }

      context 'the license is invalid' do
        before { described_class.stub(:check_intelligence_license).and_return false }

        it 'should not create any link' do
          Ghost.should_not_receive :create_and_link_entity
          described_class.process_evidence entity, evidence
        end
      end

      context 'the license is valid' do
        before { described_class.stub(:check_intelligence_license).and_return true }

        it 'should create a link' do
          Ghost.should_receive :create_and_link_entity
          described_class.process_evidence entity, evidence
        end
      end
    end
  end


  describe '#process_aggregate' do
    pending
  end
end

end
end