require 'spec_helper'
require_db 'db_layer'
require_db 'grid'

describe Evidence do

  use_db
  silence_alerts

  describe '#common_filter' do

    # "params" could be:

    # default
    # {"filter"=>
    # "{\"from\":\"24h\",\"target\":\"4f86902a2afb6512a700006f\",\"agent\":\"5008225c2afb654a4f003b9b\",\"date\":\"dr\"}"}

    # unchecking "Received"
    # {"filter"=>
    # "{\"from\":0,\"target\":\"4f86902a2afb6512a700006f\",\"to\":0,\"agent\":\"5008225c2afb654a4f003b9b\",\"date\":\"da\"}"}

    # checking some type in the "type" column
    # {"filter"=>
    # "{\"agent\":\"5008225c2afb654a4f003b9b\",\"from\":0,\"target\":\"4f86902a2afb6512a700006f\",\"to\":0,\"date\":\"da\",
    # \"type\":[\"device\",\"file\",\"keylog\"]}"}

    # writing something in the "info" text area
    # {"filter"=>
    # "{\"info\":\"pippo pluto\",\"agent\":\"5008225c2afb654a4f003b9b\",\"from\":0,\"target\":\"4f86902a2afb6512a700006f\",\"to\":0,
    # \"date\":\"da\",\"type\":[\"device\",\"file\",\"keylog\"]}"}

    let(:operation) { Item.create!(name: 'op1', _kind: :operation, path: [], stat: ::Stat.new) }

    let(:target) { Item.create!(name: 'target1', _kind: :target, path: [operation.id], stat: ::Stat.new) }

    let(:filter) { {"from" => "24h", "target" => "a_target_id", "agent" => "an_agent_id", "date" => "dr"} }

    let(:params) { {"filter" => filter} }

    let(:params_with_invalid_filter) { {'filter' => 'invalid_json'} }

    it 'raises an error if the "filter" could not be parsed to JSON' do
      expect{ described_class.common_filter(params_with_invalid_filter) }.to raise_error JSON::ParserError
    end

    context 'when the target cannot be found' do

      it 'returns nil without raising errors' do
        expect(described_class.common_filter params).to be_nil
      end
    end

    context 'when the target exists' do

      #build the target and puts its id in the 'filter' hash
      before { params['filter']['target'] = target.id }

      it 'returns the target' do
        ary = described_class.common_filter params
        expect(ary.last).to eql target
      end
    end

    context 'when an hash without the "filter" key is passed' do

      it 'returns nil without raising errors' do
        expect(described_class.common_filter({})).to be_nil
      end
    end

    describe "the returned filter_hash" do

      let(:filter) { {"from" => "24h", "target" => "a_target_id", "agent" => "an_agent_id", "info" => "asd lol"} }

      let :filter_hash do
        params['filter']['target'] = target.id
        described_class.common_filter(params)[1]
      end

      it 'contains the agent id (even if the agent is missing in the db)' do
        expect(filter_hash[:aid]).to eql 'an_agent_id'
      end

      # note: da stans for date aquired
      it 'uses the "da" attribute if no "date" is given' do
        filter_on_da = filter_hash.select { |key| key.respond_to?(:name) and key.name == :da }
        expect(filter_on_da).not_to be_empty
      end

      # note: kw stands for keywords
      it 'contains a filter on the :kw attribute when params contains "info"' do
        filter_on_kw = filter_hash.select { |key| key.respond_to?(:name) and key.name == :kw }
        expect(filter_on_kw).not_to be_empty
      end
    end
  end

  describe '#parse_info_keywords' do

    let(:info) { 'john dorian skype' }

    let(:filter) { {'info' => info} }

    let(:filter_hash) { {} }

    it 'adds to the filter_hash a selector on the :kw attribute' do
      described_class.parse_info_keywords filter, filter_hash
      selector = filter_hash.keys.first
      expect(selector.name).to eql :kw
      expect(selector.operator).to eql '$all'
    end
  end
end
