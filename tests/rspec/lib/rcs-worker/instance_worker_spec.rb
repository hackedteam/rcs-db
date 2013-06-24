require 'spec_helper'
require_worker 'instance_worker'

module RCS::Worker
  describe InstanceWorker do

    describe '#save_evidence' do
      pending
    end
  end
end

# Remove the RCS::Evidence class defined by rcs-common/evidence
if defined? RCS::Evidence
  RCS.send :remove_const, 'Evidence'
end
