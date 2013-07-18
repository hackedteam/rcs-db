require 'spec_helper'
require_worker 'instance_worker'

module RCS::Worker
  describe InstanceWorker do

    silence_alerts
    enable_license

    describe '#save_evidence' do

      let!(:target) { factory_create :target }

      let!(:agent) { factory_create :agent, target: target }

      let!(:evidence) { factory_create :chat_evidence, target: target }

      def subject(instance_variables = {})
        eval 'class InstanceWorker; def initialize; end; end;'
        described_class.new.tap do |inst|
          instance_variables.each { |k, v| inst.instance_variable_set("@#{k}", v) }
        end
      end

      context 'when the evidence must be discarded due to matching connectors rules' do

        before { RCS::DB::ConnectorManager.stub(:process_evidence).and_return(:discard) }

        it 'does not adds the evidence to the other queues' do
          RCS::DB::ConnectorManager.should_receive(:process_evidence).with(target, evidence)
          [OCRQueue, TransQueue, AggregatorQueue, IntelligenceQueue].each { |klass| klass.should_not_receive(:add) }
          subject(target: target, agent: agent).save_evidence(evidence)
        end
      end

      context 'when the evidence must not be discarded accoding to (eventually) matching connectors' do

        before { RCS::DB::ConnectorManager.stub(:process_evidence).and_return(:keep) }

        it 'Adds the evidence to the other queues' do
          RCS::DB::ConnectorManager.should_receive(:process_evidence).with(target, evidence)
          [OCRQueue, IntelligenceQueue].each { |klass| klass.should_not_receive(:add) }
          [TransQueue, AggregatorQueue].each { |klass| klass.should_receive(:add) }
          subject(target: target, agent: agent).save_evidence(evidence)
        end
      end

      context 'when the evidence match a watche item' do
        pending
      end
    end
  end
end

# Remove the RCS::Evidence class defined by rcs-common/evidence
if defined? RCS::Evidence
  RCS.send :remove_const, 'Evidence'
end
