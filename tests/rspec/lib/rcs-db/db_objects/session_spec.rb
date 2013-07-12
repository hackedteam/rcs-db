require 'spec_helper'
require_db 'db_layer'

describe Session do

  it 'defines some indexes' do
    expect(described_class.index_options).to have_key(user_id: 1)
    expect(described_class.index_options).to have_key(cookie: 1)
  end

  context 'when a session is created or destroyed' do

    let(:user) { factory_create(:user) }

    it 'builds the dashboard ids whitelist' do
      described_class.any_instance.should_receive(:rebuild_dashboard_whitelist).twice
      session = factory_create(:session, user: user)
      session.destroy
    end
  end
end
