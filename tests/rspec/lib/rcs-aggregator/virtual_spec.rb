require 'spec_helper'
require_db 'db_layer'
require_aggregator 'virtual'

module RCS
module Aggregator

describe VirtualAggregator do

  let(:subject) { described_class }

  before { turn_off_tracer }

  describe '#extract' do
    let(:url_evidence) do
      Evidence.dynamic_new('testtarget').tap do |e|
        e.data = {'url' => 'http://it.wikipedia.org/wiki/Tim_Berners-Lee', 'program' => 'chrome'}
        e.type = :url
      end
    end

    it 'return the data needed to create an aggregate' do
      hash = subject.extract(url_evidence).first
      expect(hash[:type]).to eql :url
      expect(hash[:host]).to eql 'it.wikipedia.org'
    end
  end

  describe '#host' do

    it 'returns nil when the url is missing or invalid' do
      expect(subject.host(nil)).to be_nil
      expect(subject.host('not_and_url')).to be_nil
    end

    it 'returns the host downcased without "www."' do
      expect(subject.host('http://it.wikipedia.org/wiki/Tim_Berners-Lee')).to eql 'it.wikipedia.org'
      expect(subject.host('http://www.it.WIKIPEDIA.org/wiki/Tim_Berners-Lee')).to eql 'it.wikipedia.org'
    end

    it 'returns a valid host even when the uri scheme is missing' do
      pending "What to assume a default scheme in these cases?"
      # expect(subject.host('it.wikipedia.org/wiki/Tim_Berners-Lee')).to eql 'it.wikipedia.org'
    end
  end
end

end
end
