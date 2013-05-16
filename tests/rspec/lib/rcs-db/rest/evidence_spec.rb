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

    let(:first_evidence) { Evidence.collection_class(target.id).create!(kw: %w[ciao miao bau], da: Time.now.to_i-100, aid: agent.id, type: :chat, data: chat_data) }

    let(:second_evidence) { Evidence.collection_class(target.id).create!(kw: %w[roflmao lol asd ciao], da: Time.now.to_i-100, aid: agent.id, type: :chat, data: chat_data) }

    let(:third_evidence) { Evidence.collection_class(target.id).create!(kw: %w[steve jobs], da: Time.now.to_i-100, aid: agent.id, type: :chat, data: chat_data, note: "steve jobs") }

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

        # create the evidences
        first_evidence
        second_evidence
        third_evidence
      end

      context 'when "info" is provided' do

        let(:common_filters) { {"from" => "24h", "target" => target.id, "agent" => agent.id} }

        it 'return the matching evidences' do
          criteria = index_with_params 'filter' => common_filters.merge("info" => ["bau ciao"])
          expect(criteria.size).to eql 1
          expect(criteria.first).to eql first_evidence

          criteria = index_with_params 'filter' => common_filters.merge("info" => ["bau", "ciao"])
          expect(criteria.size).to eql 2
          expect(criteria.entries).to include first_evidence
          expect(criteria.entries).to include second_evidence

          criteria = index_with_params 'filter' => common_filters.merge("info" => ["bau ciao muu"])
          expect(criteria.entries).to be_empty

          criteria = index_with_params 'filter' => common_filters.merge("info" => "bau ciao")
          expect(criteria.size).to eql 1
          expect(criteria.first).to eql first_evidence

          criteria = index_with_params 'filter' => common_filters.merge("info" => ["steve", "ciao"])
          expect(criteria.size).to eql 3
        end
      end

      context 'when "note" is provided' do

        let(:common_filters) { {"from" => "24h", "target" => target.id, "agent" => agent.id} }

        it 'return the matching evidences' do
          criteria = index_with_params 'filter' => common_filters.merge("note" => ["steve"])
          expect(criteria.size).to eql 1
          expect(criteria.first).to eql third_evidence

          criteria = index_with_params 'filter' => common_filters.merge("note" => ["steve jobs"])
          expect(criteria.size).to eql 1

          criteria = index_with_params 'filter' => common_filters.merge("note" => ["jobs steve"])
          expect(criteria.size).to eql 0

          criteria = index_with_params 'filter' => common_filters.merge("note" => ["jobs steve ciao"])
          expect(criteria.size).to eql 0

          criteria = index_with_params 'filter' => common_filters.merge("note" => ["jobs xxx"])
          expect(criteria.entries).to be_empty

          criteria = index_with_params 'filter' => common_filters.merge("note" => ["jobs", "xxx"])
          expect(criteria.size).to eql 1
          expect(criteria.first).to eql third_evidence

          criteria = index_with_params 'filter' => common_filters.merge("note" => ["jobs xxx", "yyyy"])
          expect(criteria.entries).to be_empty
        end
      end

      context 'when "note" is provided with "info"' do

        let(:common_filters) { {"from" => "24h", "target" => target.id, "agent" => agent.id} }

        it 'return the matching evidences' do
          criteria = index_with_params 'filter' => common_filters.merge("note" => ["steve"], "info" => "steve")
          expect(criteria.size).to eql 1
          expect(criteria.first).to eql third_evidence

          criteria = index_with_params 'filter' => common_filters.merge("note" => ["xxx jobs"], "info" => ["ciao"])
          expect(criteria.size).to eql 0

          criteria = index_with_params 'filter' => common_filters.merge("note" => ["jobs steve"], "info" => ["steve jobs", "ciao"])
          expect(criteria.entries).to be_empty
        end
      end
    end
  end

end
end
