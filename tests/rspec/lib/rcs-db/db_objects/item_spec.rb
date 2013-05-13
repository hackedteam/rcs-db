require 'spec_helper'
require_db 'db_layer'

describe Stat do
  context 'when initialized without any parameters' do

    it 'assigns a default value to some attributes' do
      expect(subject.size).to eql 0
      expect(subject.grid_size).to eql 0
      expect(subject.evidence).to eql Hash.new
      expect(subject.dashboard).to eql Hash.new
    end
  end
end

describe Item do

  it 'uses the RCS::Tracer module' do
    expect(described_class).to respond_to :trace
    expect(subject).to respond_to :trace
  end

  context 'when initialized without any parameters' do

    it 'assigns a default value to some attributes' do
      expect(subject.deleted).to be_false
      expect(subject.demo).to be_false
      expect(subject.scout).to be_false
      expect(subject.upgradable).to be_false
      expect(subject.purge).to eql [0, 0]
      expect(subject.good).to be_true
    end
  end

  it 'embeds one Stat' do
    expect(subject).to respond_to :stat
  end
end
