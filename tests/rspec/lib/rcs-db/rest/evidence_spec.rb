require 'spec_helper'
require_db 'db_layer'
require_db 'evidence_manager'
# require_db 'evidence_dispatcher'
# require_db 'position/resolver'
# require_db 'connectors'

module RCS
module DB

  describe EvidenceController do

    use_db

    let(:operation) { Item.create!(name: 'testoperation', _kind: :operation, path: [], stat: ::Stat.new) }

    let(:target) { Item.create!(name: 'testtarget', _kind: :target, path: [operation.id], stat: ::Stat.new) }

    let(:agent) { Item.create!(name: 'testagent', _kind: :agent, path: target.path+[target.id], stat: ::Stat.new) }

    let(:chat_data) { {'from' => 'john', 'rcpt' => 'receiver', 'incoming' => 1, 'program' => 'skype', 'content' => 'all your base are belong to us'} }

    let(:chat_evidence) { Evidence.collection_class(target.id).create!(da: Time.now.to_i-100, aid: agent.id, type: :chat, data: chat_data, kw: %w[ciao miao bau]) }


    describe '#index' do

      def index_with_params params
        subject.instance_variable_set '@params', params
        subject.index
      end

      before do
        # skip check of current user privileges
        subject.stub :require_auth_level

        # stub the #ok method and then #not_found methods
        subject.stub(:ok) { |query, options| query }
        subject.stub(:not_found) { |message| message }
      end

      context 'when all the keywords (info) are founded' do

        let(:filter) { {"from" => "24h", "target" => target.id, "agent" => agent.id, "info" => "bau ciao"} }

        # create the chat evidence
        before { chat_evidence }

        it 'return the matching evidences ($all search)' do
          criteria = index_with_params 'filter' => filter
          expect(criteria.first).to eql chat_evidence
        end
      end

      context 'when not all the keywords (info) are founded' do

        let(:filter) { {"from" => "24h", "target" => target.id, "agent" => agent.id, "info" => "bau ciao muu"} }

        # create the chat evidence
        before { chat_evidence }

        it 'returns nothing ($all search)' do
          criteria = index_with_params 'filter' => filter
          expect(criteria.first).to be_nil
        end
      end

      context "when the keywords are piped" do

        let(:filter) { {"from" => "24h", "target" => target.id, "agent" => agent.id, "info" => "bau |muu"} }

        it 'returns the matching evidences' do
          pending
        end
      end
    end
  end

end
end
