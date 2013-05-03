require 'spec_helper'
require_db 'db_layer'
require_db 'grid'
require_intelligence 'accounts'

module RCS
module Intelligence

  describe Accounts do
    before do
      turn_off_tracer
      connect_mongoid
      empty_test_db
      Entity.any_instance.stub(:alert_new_entity).and_return nil
      EntityHandle.any_instance.stub(:check_intelligence_license).and_return true
    end

    after { empty_test_db }

    let(:operation) { Item.create!(name: 'test-operation', _kind: 'operation', path: [], stat: ::Stat.new) }
    let(:target) { Item.create!(name: 'test-target', _kind: 'target', path: [operation._id], stat: ::Stat.new) }
    let(:agent) { Item.create!(name: 'test-agent', _kind: 'agent', path: target.path+[target._id], stat: ::Stat.new) }
    let(:target_entity) { Entity.any_in({path: [target._id]}).first }
    let(:known_program) { described_class.addressbook_types.sample }

    def create_addressbook_evidence data
      Evidence.collection_class(target._id).create!(da: Time.now.to_i, aid: agent._id, type: 'addressbook', data: data)
    end

    def add_handle_to_target_entity attributes
      entity_handle = EntityHandle.new(attributes)
      target_entity.handles << entity_handle
      target_entity.save!
      entity_handle
    end


    it 'should use the Tracer module' do
      described_class.should respond_to :trace
      subject.should respond_to :trace
    end


    describe '#add_handle' do
      context 'the evidence belongs to a known program' do
        let(:evidence) { create_addressbook_evidence 'program' => known_program, 'handle' => 'j.snow' }

        context "and the type is :target" do
          before { evidence[:data]['type'] = :peer }

          it 'do nothing' do
            described_class.should_not_receive :create_entity_handle
            described_class.add_handle target_entity, evidence
          end
        end

        context "and the type is not :target" do
          before { evidence[:data]['type'] = :target }

          it 'creates or update an EntityHandle' do
            # create
            described_class.add_handle target_entity, evidence
            target_entity.handles.size.should == 1
            target_entity.handles.first.name.should be_nil

            # and update
            evidence[:data]['name'] = 'John Snow'
            described_class.add_handle target_entity, evidence
            target_entity.handles.size.should == 1
            target_entity.handles.first.name.should == 'John Snow'
          end
        end
      end

      context 'the evidence program is :outlook or :mail (or un unkonw program)' do
        %w[outlook mail unk0wn].each do |program_name|
          context "when the program name is \"#{program_name}\"" do
            let(:evidence) { create_addressbook_evidence 'program' => program_name, 'user' => 'jshow1', 'service' => 'gmail' }

            it 'create or update an EntityHandle' do
              described_class.should_receive(:create_entity_handle_from_user).once
              described_class.add_handle target_entity, evidence
            end
          end
        end
      end
    end

    describe '#create_entity_handle_from_user' do
      let(:entity_handle) { described_class.create_entity_handle_from_user target_entity, 'jshow1', 'google' }

      it 'create an EntityHandle' do
        entity_handle.handle.should == 'jshow1@gmail.com'
        entity_handle.type.should == :gmail
        entity_handle.level.should == :automatic
        entity_handle.name.should == ''
      end

      context 'an EntityHandle with the same handle alredy exists' do
        before { entity_handle }

        it 'shuld not create another EntityHandle' do
          entity_handle
          target_entity.handles.size.should == 1
        end
      end

      context 'no valid mail can be extracted from the username and the service' do
        before { described_class.create_entity_handle_from_user target_entity, 'jshow1', 'yahoo' }

        it 'should not create an EntityHandle' do
          target_entity.handles.size.should == 0
        end
      end
    end

    describe '#create_entity_handle' do
      let!(:existing_entity_handle) { add_handle_to_target_entity(level: :automatic, type: :target, name: 'John Snow', handle: 'j.snow') }
      before { target_entity.handles.should == [existing_entity_handle] }

      context 'name, handle and type match an existing EntityHandle' do
        it 'do nothing' do
          described_class.create_entity_handle target_entity, :target, 'j.snow', 'John Snow'
          target_entity.handles.size.should == 1
        end
      end

      context 'type and handle match an existing EntityHandle' do
        context 'the existing EntityHandle has an empty name' do
          before { existing_entity_handle.update_attributes name: nil }

          it 'should update the name attribute of the existing EntityHandle' do
            new_name = 'Rob Stark'
            described_class.create_entity_handle(target_entity, :target, 'j.snow', new_name)
            target_entity.handles.size.should == 1
            target_entity.handles.first.name.should == new_name
          end
        end

        context 'the existing EntityHandle has a valid name' do
          it 'should keep the name attribute of the existing EntityHandle' do
            new_name = 'Rob Stark'
            described_class.create_entity_handle(target_entity, :target, 'j.snow', new_name)
            target_entity.handles.size.should == 1
            target_entity.handles.first.name.should == existing_entity_handle.name
          end
        end
      end

      context 'type and handle are not found in any existing EntityHandle' do
        it 'should create a new EntityHandle' do
          described_class.create_entity_handle(target_entity, :target, 'a.stark', 'Arya Stark')
          target_entity.handles.size.should == 2
        end
      end
    end


    describe '#addressbook_types' do
      it 'should not include "outlook"' do
        described_class.addressbook_types.should_not include :outlook
      end

      it 'should not include "mail"' do
        described_class.addressbook_types.should include :mail
      end
    end


    describe '#get_type' do
      context 'the user is a valid email addr' do
        before { described_class.stub(:is_mail?).and_return true }

        {'john@gmail.com' => :gmail, 'snow@facebook.com' => :facebook, 's.jobs@apple.com' => :mail}.each do |user, expected_type|
          it "should returns the expectd type (#{expected_type})" do
            service = "will_be_ignored"
            described_class.get_type(user, service).should == expected_type
          end
        end
      end

      context 'the user is not a valid email addr' do
        before { described_class.stub(:is_mail?).and_return false }

        {'gmail' => :gmail, 'facebook' => :facebook, 'apple.com' => :mail}.each do |service, expected_type|
          it "should returns the expectd type (#{expected_type})" do
            user = "invalid_email"
            described_class.get_type(user, service).should == expected_type
          end
        end
      end
    end


    describe '#get_addressbook_handle' do
      let(:evidence) do
        evidence = Evidence.dynamic_new('testtarget')
        evidence[:data] = {}
        evidence
      end

      context 'the evidence "program" is unknown' do
        it ('returns nil') { described_class.get_addressbook_handle(evidence).should be_nil }
      end

      context 'the evidence "program" is known' do
        before { evidence[:data]['program'] = known_program }

        context 'and the type is :target' do
          before { evidence[:data]['type'] = :target }
          it ('returns nil') { described_class.get_addressbook_handle(evidence).should be_nil }
        end

        context 'or there is no handle' do
          it ('returns nil') { described_class.get_addressbook_handle(evidence).should be_nil }
        end

        context 'and the type not :target and the is and handle' do
          before do
            @expectd_result = ['John Snow', known_program, 'john.snow']
            evidence[:data]['type'] = :peer
            evidence[:data]['handle'] = 'JoHn.SnOw'
            evidence[:data]['name'] = 'John Snow'
          end

          it 'returns an array with name, program and handle' do
            described_class.get_addressbook_handle(evidence).should == @expectd_result
          end
        end
      end
    end


    describe '#is_mail?' do
      context 'when the email is empty' do
        it('returns false') { described_class.is_mail?('').should be_false }
      end

      context 'when the email is nil' do
        it('returns false') { described_class.is_mail?(nil).should be_false }
      end

      context 'when the email is invalid' do
        it('returns false') { described_class.is_mail?('asd@').should be_false }
      end

      context 'when the email is valid' do
        it('returns true') { described_class.is_mail?('asd@asd.com').should be_true }
      end
    end


    describe '#add_domain' do
      let(:username) { 'john_snow' }
      google = 'google'

      context 'the username is not a valid email addr' do
        before { described_class.stub(:is_mail?).and_return false }

        %w[gmail facebook].each do |service_name|
          context "the service name contains the word \"#{service_name}\"" do

            it 'should adds the domain name to the username' do
              described_class.add_domain(username, service_name)
              username.should =~ /.+#{service_name}.+/
            end
          end
        end

        context "the service name contains the word \"#{google}\"" do
          it 'should adds the gmail.com domain' do
            described_class.add_domain(username, google)
            username.should =~ /\A.+\@gmail\.com\z/
          end
        end
      end

      context 'the username is alredy a valid email address' do
        before { described_class.stub(:is_mail?).and_return true }

        it 'should returns the username without adding any domain name' do
          original_username = username.dup
          described_class.add_domain username, google
          username.should == original_username
        end
      end
    end
  end

end
end
