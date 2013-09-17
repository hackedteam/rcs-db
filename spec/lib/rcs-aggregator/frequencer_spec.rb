require 'spec_helper'
require_db 'db_layer'
require_aggregator 'frequencer'

module RCS
module Aggregator


describe Frequencer do

  def feeder(frequencer, peer, days, freq_in, freq_out)

    days.times do |day|
      freq_in.times do
        frequencer.feed(Time.now + 86400*day, peer, :in) do |peer|
          yield peer
        end
      end
      freq_out.times do
        frequencer.feed(Time.now + 86400*day, peer, :out) do |peer|
          yield peer
        end
      end
    end

    # make sure the window is filled by inserting the last element
    frequencer.feed(Time.now + 86400*(Frequencer::WINDOW_SIZE + 1), peer, :in) do |peer|
      yield peer
    end
  end

  it 'should fill the date holes' do
    frequencer = Frequencer.new

    # feed an entry for now
    frequencer.feed(Time.now, 'peer', :in)
    # and in 5 days
    frequencer.feed(Time.now + 86400*5, 'peer', :in)

    matrix = frequencer.instance_variable_get(:@analysis)
    matrix.size.should be 6
  end

  it 'should dump the current status' do
    frequencer = Frequencer.new
    frequencer.feed(Time.now, 'peer', :in)

    dump = frequencer.dump
    dup = Frequencer.new_from_dump(dump)

    # check that the value are identical
    dup.instance_variables.each do |var|
      dup.instance_variable_get(var).should eq frequencer.instance_variable_get(var)
    end
  end

  context 'given a low interaction peer' do
    it 'should not emit any peer (not enough two way factor)' do
      frequencer = Frequencer.new

      outputs = []
      feeder(frequencer, 'test', Frequencer::WINDOW_SIZE + 1, 1, 0) do |peer|
        outputs << peer
      end

      outputs.should be_empty
    end

    it 'should not emit any peer (not enough daily frequency)' do
      frequencer = Frequencer.new

      outputs = []
      feeder(frequencer, 'test', 2, 2, 2) do |peer|
        outputs << peer
      end

      outputs.should be_empty
    end
  end

  context 'given a high interaction peer (spammer)' do
    it 'should not emit any peer (too much one way factor)' do
      frequencer = Frequencer.new

      outputs = []
      feeder(frequencer, 'test', Frequencer::WINDOW_SIZE + 1, 10, 1) do |peer|
        outputs << peer
      end

      outputs.should be_empty
    end
  end

  context 'given a high interaction peer (balanced)' do
    it 'should emit the peer (everyday 2 in and 2 out)' do
      frequencer = Frequencer.new

      outputs = []
      feeder(frequencer, 'test', Frequencer::WINDOW_SIZE + 1, 2, 2) do |peer|
        outputs << peer
      end

      outputs.should_not be_empty
    end

    it 'should emit the peer (3 days 1 in and 1 out)' do
      frequencer = Frequencer.new

      outputs = []
      feeder(frequencer, 'test', 4, 1, 1) do |peer|
        outputs << peer
      end

      outputs.should_not be_empty
    end

  end


end

end
end
