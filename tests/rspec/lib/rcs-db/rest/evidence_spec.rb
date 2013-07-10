require 'spec_helper'
require_db 'db_layer'
require_db 'evidence_manager'

module RCS
module DB

  describe EvidenceController do


    let!(:target) { factory_create(:target) }
    let!(:agent) { factory_create(:agent, target: target) }

    let!(:evidence1) { factory_create(:chat_evidence, agent: agent, kw: %w[ciao miao bau]) }
    let!(:evidence2) { factory_create(:chat_evidence, agent: agent, kw: %w[roflmao lol asd ciao]) }
    let!(:evidence3) { factory_create(:chat_evidence, agent: agent, kw: %w[steve jobs], note: "steve jobs") }
    let!(:evidence4) { factory_create(:position_evidence, agent: agent) }
    let!(:evidence5) { factory_create(:position_evidence, agent: agent, data:{latitude: 30, longitude: 30}, da: Time.now.to_i - 2.days) }

    before do
      # skip check of current user privileges
      described_class.any_instance.stub :require_auth_level

      # stub the #ok method and then #not_found methods
      described_class.any_instance.stub(:ok) { |query, options| query }
      described_class.any_instance.stub(:not_found) { |message| message }
    end

    # Make @params args of the contructor for test purposes.
    def subject(params = {})
      described_class.new.tap { |inst| inst.instance_variable_set('@params', params) }
    end

    describe '#index' do

      def index(params)
        instance = subject(params)
        result = instance.index

        # Expect the result of #index to be the same size of
        # the result of #count.
        cnt = result.count
        cnt = -1 if cnt == 0
        expect(cnt).to eql instance.count

        result
      end

      context 'when "info" is provided' do

        let(:common_filters) { {"from" => "24h", "target" => target.id, "agent" => agent.id} }

        it 'return the matching evidences' do
          criteria = index 'filter' => common_filters.merge("info" => ["bau ciao"])
          expect(criteria.size).to eql 1
          expect(criteria.first).to eql evidence1

          criteria = index 'filter' => common_filters.merge("info" => ["bau", "ciao"])
          expect(criteria.size).to eql 2
          expect(criteria.entries).to include evidence1
          expect(criteria.entries).to include evidence2

          criteria = index 'filter' => common_filters.merge("info" => ["bau ciao muu"])
          expect(criteria.entries).to be_empty

          criteria = index 'filter' => common_filters.merge("info" => "bau ciao")
          expect(criteria.size).to eql 1
          expect(criteria.first).to eql evidence1

          criteria = index 'filter' => common_filters.merge("info" => ["steve", "ciao"])
          expect(criteria.size).to eql 3
        end

        it 'return the matching evidences (search using $near)' do
          criteria = index 'filter' => common_filters.merge("info" => ["lon:9.1915256,lat:45.4766561,r:500"])
          expect(criteria.first).to eql evidence4

          criteria = index 'filter' => common_filters.merge("info" => ["lon:9.1915256,lat:45.4766561,r:500"])
          expect(criteria.first).to eql evidence4

          criteria = index 'filter' => common_filters.merge("info" => ["lon:9.19,lat:45.47,r:100"])
          expect(criteria.first).to be_nil

          criteria = index 'filter' => common_filters.merge("info" => ["lon:9.19,lat:45.47,r:1000"])
          expect(criteria.first).to eql evidence4

          criteria = index 'filter' => common_filters.merge("info" => ["lon:30.0,lat:30.0,r:5000"])
          expect(criteria.first).to be_nil
        end
      end

      context 'when "note" is provided' do

        let(:common_filters) { {"from" => "24h", "target" => target.id, "agent" => agent.id} }

        it 'return the matching evidences' do
          criteria = index 'filter' => common_filters.merge("note" => ["steve"])
          expect(criteria.size).to eql 1
          expect(criteria.first).to eql evidence3

          criteria = index 'filter' => common_filters.merge("note" => ["steve jobs"])
          expect(criteria.size).to eql 1

          criteria = index 'filter' => common_filters.merge("note" => ["jobs steve"])
          expect(criteria.size).to eql 0

          criteria = index 'filter' => common_filters.merge("note" => ["jobs steve ciao"])
          expect(criteria.size).to eql 0

          criteria = index 'filter' => common_filters.merge("note" => ["jobs xxx"])
          expect(criteria.entries).to be_empty

          criteria = index 'filter' => common_filters.merge("note" => ["jobs", "xxx"])
          expect(criteria.size).to eql 1
          expect(criteria.first).to eql evidence3

          criteria = index 'filter' => common_filters.merge("note" => ["jobs xxx", "yyyy"])
          expect(criteria.entries).to be_empty
        end
      end

      context 'when "note" is provided with "info"' do

        let(:common_filters) { {"from" => "24h", "target" => target.id, "agent" => agent.id} }

        it 'return the matching evidences' do
          criteria = index 'filter' => common_filters.merge("note" => ["steve"], "info" => "steve")
          expect(criteria.size).to eql 1
          expect(criteria.first).to eql evidence3

          criteria = index 'filter' => common_filters.merge("note" => ["xxx jobs"], "info" => ["ciao"])
          expect(criteria.size).to eql 0

          criteria = index 'filter' => common_filters.merge("note" => ["jobs steve"], "info" => ["steve jobs", "ciao"])
          expect(criteria.entries).to be_empty
        end
      end
    end

    describe '#total' do
      pending
    end
  end

end
end
