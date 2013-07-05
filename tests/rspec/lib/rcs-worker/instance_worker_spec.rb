require 'spec_helper'
require_worker 'instance_worker'

module RCS::Worker
  describe InstanceWorker do

    use_db
    silence_alerts
    enable_license

    describe '#save_evidence' do

      let!(:target) { factory_create :target }

      let!(:evidence) { factory_create :chat_evidence, target: target }

      def subject(instance_variables = {})
        described_class.any_instance.stub(:initialize)
        described_class.new.tap do |inst|
          instance_variables.each { |k, v| inst.instance_variable_set("@#{k}", v) }
        end
      end

      context 'when the evidence must be discarded due to matching connectors rules' do

        before { RCS::DB::Connectors.stub(:add_to_queue).and_return(:discard) }

        it 'does not adds the evidence to the other queues' do
          RCS::DB::Connectors.should_receive(:add_to_queue).with(target, evidence)
          [OCRQueue, TransQueue, AggregatorQueue, IntelligenceQueue].each { |klass| klass.should_not_receive(:add) }
          subject(target: target).save_evidence(evidence)
        end
      end

      context 'when the evidence must not be discarded accoding to (eventually) matching connectors' do

        before { RCS::DB::Connectors.stub(:add_to_queue).and_return(:keep) }

        it 'Adds the evidence to the other queues' do
          RCS::DB::Connectors.should_receive(:add_to_queue).with(target, evidence)
          [OCRQueue, IntelligenceQueue].each { |klass| klass.should_not_receive(:add) }
          [TransQueue, AggregatorQueue].each { |klass| klass.should_receive(:add) }
          subject(target: target).save_evidence(evidence)
        end
      end
    end
  end
end

# Remove the RCS::Evidence class defined by rcs-common/evidence
if defined? RCS::Evidence
  RCS.send :remove_const, 'Evidence'
end
