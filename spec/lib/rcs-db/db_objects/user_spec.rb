require 'spec_helper'
require_db 'db_layer'
require_db 'grid'

describe User do

  describe '#online' do

    it 'is a scope' do
      expect(described_class.online).to be_kind_of(Mongoid::Criteria)
    end

    let(:online_users) { User.all.to_a[0..1] }

    before do
      3.times { factory_create(:user) }
      online_users.each { |u| factory_create(:session, user: u) }
    end

    it 'returns online users' do
      expect(described_class.online.to_a.sort).to eql(online_users.sort)
    end
  end

  describe '#password_expiring?' do

    let (:user) { factory_create(:user) }

    before do
      user.stub(:password_never_expire?).and_return(false)

      expect(user.password_expiring?).to be_false
      expect(user.pwd_changed_at.to_date).to eq(Time.now.utc.to_date)
    end

    context 'when a user has changed the password recently' do

      before { user.reset_pwd_changed_at(Time.now.utc - 10*24*3600) }

      it 'returns false' do
        expect(user.password_expiring?).to be_false
      end
    end

    context 'when a user has changed the password 87 days ago' do

      before { user.reset_pwd_changed_at(Time.now.utc - 3*29*24*3600) }

      it 'returns true' do
        expect(user.password_expiring?).to be_true
      end
    end
  end

  describe '#password_never_expire?' do

    let(:user) { factory_create(:user) }

    context 'when the PASSWORDS_NEVER_EXPIRE flag is set' do

      before { RCS::DB::Config.instance.global['PASSWORDS_NEVER_EXPIRE'] = 1 }

      it 'returns true' do
        expect(user.password_never_expire?).to be_true
      end
    end

    context 'when the PASSWORDS_NEVER_EXPIRE flag is not' do

      before { RCS::DB::Config.instance.global['PASSWORDS_NEVER_EXPIRE'] = nil }

      it 'returns false' do
        expect(user.password_never_expire?).to be_false
      end
    end

    context 'when the user has the pwd_changed_at (and pwd_changed_cs) attributes missing (not migrated yet)' do

      before do
        user.update_attribute(:pwd_changed_at, nil)
        user.update_attribute(:pwd_changed_cs, nil)
      end

      it 'returns true' do
        expect(user.password_never_expire?).to be_true
      end
    end
  end

  describe '#password_expired?' do

    let (:user) { factory_create(:user) }

    before do
      user.stub(:password_never_expire?).and_return(false)

      expect(user.password_expired?).to be_false
      expect(user.pwd_changed_at.to_date).to eq(Time.now.utc.to_date)
    end

    context 'when a user has changed the password recently' do

      before { user.reset_pwd_changed_at(Time.now.utc - 10*24*3600) }

      it 'returns false' do
        expect(user.password_expired?).to be_false
      end

      context 'the PASSWORDS_NEVER_EXPIRE flag is set' do

        before { user.stub(:password_never_expire?).and_return(true) }

        it 'returns false' do
          expect(user.password_expired?).to be_false
        end
      end
    end

    context 'when a user has changed the password at least 3 months ago' do

      before { user.reset_pwd_changed_at(Time.now.utc - 31*3*24*3600) }

      it 'returns true' do
        expect(user.password_expired?).to be_true
      end

      context 'the PASSWORDS_NEVER_EXPIRE flag is set' do

        before { user.stub(:password_never_expire?).and_return(true) }

        it 'returns false' do
          expect(user.password_expired?).to be_false
        end
      end
    end

    context 'when a user has modified the pwd_changed_at via mongodb' do

      before do
        described_class.collection.find(_id: user.id).update('$set' => {pwd_changed_at: Time.now.utc - 3*3600})
        user.reload
      end

      it 'returns true' do
        expect(user.password_expired?).to be_true
      end
    end
  end

  describe "#password_changed?" do

    context 'when the user is initialize (even with no password)' do

      it 'returns true' do
        expect(described_class.new.password_changed?).to be_true
        expect(described_class.new(pass: 'a').password_changed?).to be_true
      end
    end

    context "when an existing user changes his password" do

      let(:user) { User.create(name: 'foo', pass: 'bar f00 BAR') }

      before do
        expect(user.password_changed?).to be_false
        user.pass = 'foo'
      end

      it 'returns true' do
        expect(user.password_changed?).to be_true
      end
    end
  end

  context 'when an user is initialized with a valid password' do

    let(:strong_password) { 'foo bar f00 BAR' }

    let(:user) { described_class.new(pass: strong_password) }

    it 'is valid' do
      expect(user.valid?).to be_true
    end

    context 'when saved' do

      before { user.save! }

      it 'it stores the hashed password correctly' do
        expect(user.pass).not_to eq(strong_password)
        expect(user.has_password?(strong_password))
      end

      context 'when another attributes is changed' do

        before { user.update_attributes(name: 'bob') }

        it 'does not double-hash the password' do
          expect(user.has_password?(strong_password))
        end
      end
    end
  end

  context 'when an user is initialized with a password that match his name' do

    let(:user) { described_class.new(name: 'bar', pass: 'foo bar f00 BAR') }

    it 'is not valid' do
      expect(user.valid?).to be_false
    end
  end

  context 'when an user is initialized with an invalid password' do

    let(:user) { described_class.new(pass: 'foo') }

    it 'is not valid' do
      expect(user.valid?).to be_false
    end
  end

  context 'when a user is created with an invalid password' do

    it 'raises an error' do
      user = described_class.new(pass: 'foo')
      expect { user.save! }.to raise_error(Mongoid::Errors::Validations)
      expect { described_class.create!(pass: 'foo') }.to raise_error(Mongoid::Errors::Validations)
      expect(described_class.count).to eq(0)
    end
  end

  context 'when a user updates his dashboard_ids' do

    let!(:user) { factory_create(:user) }

    it 'rebuilds the watched item list' do
      described_class.any_instance.should_receive(:rebuild_watched_items)
      user.update_attributes(dashboard_ids: ['517552a0c78783c10d000005'], desc: 'i like trains')
    end
  end

  context 'when a user updates his attributes but not the dashboard_ids' do

    let!(:user) { factory_create(:user) }

    it 'does not rebuild the watched item list' do
      described_class.any_instance.should_not_receive(:rebuild_watched_items)
      user.update_attributes(desc: 'i like trains')
    end
  end

  context 'when a user is created' do

    it 'does not rebuild the watched item list' do
      described_class.any_instance.should_not_receive(:rebuild_watched_items)
      factory_create(:user)
    end
  end
end
