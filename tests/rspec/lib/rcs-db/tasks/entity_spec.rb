require 'spec_helper'
require_db 'grid'
require_db 'db_layer'
require_db 'tasks'

module RCS
module DB

  describe EntityTask do

    use_db
    silence_alerts
    enable_license
    stub_temp_folder

    let(:admin) { User.create! name: 'admin', enabled: true }

    let(:operation) do
      Item.create!(name: 'testoperation', _kind: :operation, path: [], stat: ::Stat.new).tap do |op|
        op.users << admin
      end
    end

    let(:bob) do
      target = Item.create! name: "bob", _kind: :target, path: [operation.id], stat: ::Stat.new
      Entity.any_in({path: [target.id]}).first
    end

    # Prevent Eventmachine from deferring the execution
    # of the #run method
    before { EM.stub(:defer) { |block| block.call } }

    it 'does not raise any errors' do
      task = described_class.new(:entity, 'export name', {id: bob.id})
      expect { task.run }.not_to raise_error
    end
  end

end
end
