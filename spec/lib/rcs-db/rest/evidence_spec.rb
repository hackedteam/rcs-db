require 'spec_helper'
require_db 'db_layer'

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
    let!(:evidence6) { factory_create(:mic_evidence, target: target) }

    before do
      # skip check of current user privileges
      described_class.any_instance.stub :require_auth_level

      # stub the #ok method and then #not_found methods
      described_class.any_instance.stub(:ok) { |*args| args.respond_to?(:first) && args.size == 1 ? args.first : args }
      described_class.any_instance.stub(:not_found) { |message| message }
    end

    # Make @params args of the constructor for test purposes.
    def subject(params = {})
      described_class.new.tap { |inst| inst.instance_variable_set('@params', params) }
    end

    describe '#index' do

      before { described_class.any_instance.stub(:ok) { |query, options| query } }

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

      def total(params={})
        params['filter'] = params['filter'].to_json
        subject(params).total
      end

      let(:filters) { {"from" => "0", "target" => target.id, "agent" => agent.id} }

      it 'calls not_found when the target (and/or the agent) is missing' do
        results = total('filter' => filters.merge("target" => "invalid_target_id"))
        expect(results).to match(/target not found/i)

        results = total('filter' => filters.merge("target" => "x", "agent" => "y"))
        expect(results).to match(/target not found/i)
      end


      it 'calls not_found when the agent is missing' do
        results = total('filter' => filters.merge("agent" => "z"))
        expect(results).to match(/agent not found/i)
      end

      context 'when filter by target and agent' do

        let(:results) { total('filter' => filters) }

        it 'returns the count of all the evidences grouped by type' do
          expect(results).to include(type: "chat", count: 3)
          expect(results).to include(type: "position", count: 2)
          expect(results).to include(type: "total", count: 5)

          (::Evidence::TYPES - %w[chat position total]).each do |type|
            expect(results).to include(type: type, count: 0)
          end

          expect(results.size).to eql ::Evidence::TYPES.size + 1
        end
      end

      context 'when filter by target only' do

        let(:results) { total('filter' => filters.merge("agent" => nil)) }

        it 'returns the count of all the evidences grouped by type' do
          expect(results).to include(type: "chat", count: 3)
          expect(results).to include(type: "position", count: 2)
          expect(results).to include(type: "mic", count: 1)
          expect(results).to include(type: "total", count: 6)

          (::Evidence::TYPES - %w[chat position total mic]).each do |type|
            expect(results).to include(type: type, count: 0)
          end

          expect(results.size).to eql ::Evidence::TYPES.size + 1
        end
      end
    end
  end
end
end
