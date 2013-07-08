require 'spec_helper'
require_db 'db_layer'
require_db 'grid'
require_intelligence 'passwords'

module RCS
module Intelligence

  describe Passwords do

    enable_license
    silence_alerts

    let(:operation) { Item.create!(name: 'test-operation', _kind: 'operation', path: [], stat: ::Stat.new) }

    let(:target) { Item.create!(name: 'test-target', _kind: 'target', path: [operation._id], stat: ::Stat.new) }

    let(:agent) { Item.create!(name: 'test-agent', _kind: 'agent', path: target.path+[target._id], stat: ::Stat.new) }

    let(:entity) { Entity.any_in({path: [target._id]}).first }

    let(:known_program) { subject.known_services.sample }

    def password_evidence data
      attributes = {da: Time.now.to_i, aid: agent._id, type: 'password', data: data}
      Evidence.collection_class(entity.target_id).create! attributes
    end

    it 'should use the Tracer module' do
      subject.should respond_to :trace
    end

    describe '#add_handle' do

      let(:evidence) { password_evidence 'user' => 'john', 'service' => 'gmail' }

      it 'adds an handle to the given entity' do
        subject.add_handle entity, evidence
        entity.reload
        expect(entity.handles).not_to be_empty
        expect(entity.handles.first.type).to eql :mail
      end

      context 'when the evidence is not valid' do

        let(:invalid_evidence) { password_evidence 'user' => 'john', 'service' => 'msn' }

        it 'does not add any handles' do
          subject.add_handle entity, invalid_evidence
          entity.reload
          expect(entity.handles).to be_empty
        end
      end
    end

    describe '#email_address' do
      it 'return user when user is a valid email addr' do
        expect(subject.email_address('john.snow@winterfell.com', 'winterfell')).to eql 'john.snow@winterfell.com'
      end

      it 'return an email addr when the service is known' do
        expect(subject.email_address('john.snow', 'gmail')).to eql 'john.snow@gmail.com'
        expect(subject.email_address('john.snow', 'google')).to eql 'john.snow@gmail.com'
        expect(subject.email_address('john.snow', 'outlook')).to eql 'john.snow@outlook.com'
        expect(subject.email_address('john.snow', 'facebook')).to eql 'john.snow@facebook.com'
      end

      it 'return nil when the service is not known' do
        expect(subject.email_address('john.snow', 'winterfell')).to be_nil
      end
    end

    describe '#valid_email_addr?' do
      it 'returns false when the given string is not a valid email addr' do
        ['john', '', 'john@', '@winterfell.com', 'john@.com'].each do |value|
          expect(subject.valid_email_addr?(value)).to be_false
        end
      end

      it 'returns true when the given string is a valid email addr' do
        expect(subject.valid_email_addr?('john.snow@winterfell.com')).to be_true
      end
    end

    describe '#valid_password_evidence?' do

      it 'returns false when the given evidence is not valid' do
        evidence = password_evidence 'user' => 'john'
        expect(subject.valid_password_evidence?(evidence)).to be_false

        evidence = password_evidence 'user' => 'john', 'service' => ''
        expect(subject.valid_password_evidence?(evidence)).to be_false

        evidence = password_evidence 'user' => '', 'service' => 'gmail'
        expect(subject.valid_password_evidence?(evidence)).to be_false
      end

      it 'returns true when the given evidence is valid' do
        evidence = password_evidence 'user' => 'john', 'service' => 'gmail'
        expect(subject.valid_password_evidence?(evidence)).to be_true
      end
    end
  end

end
end
