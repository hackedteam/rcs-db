#
# Aggregator processing module
#
# the evidence to be processed are queued by the workers
#

require 'date'
require 'set'

module RCS
module Aggregator

class Frequencer
  # the score over which a peer is considered relevant
  RELEVANCE_SCORE = 0.35
  # number of days to analyze in the window
  WINDOW_SIZE = 10

  attr_accessor :analysis

  def initialize(params = {})
    # auto-initialize values on access
    @analysis = Hash.new { |h,k| h[k] = Hash.new {|h,k| h[k] = Array.new(2, 0)} }
    @relevance = params[:relevance] || RELEVANCE_SCORE
    @win_size = params[:win] || WINDOW_SIZE
  end

  def dump
    copy = self.clone
    # remove the procs that cannot be mashalled
    copy.analysis.default = nil
    copy.analysis.keys.each do |k|
      copy.analysis[k].default = nil
    end
    Base64.encode64(Marshal.dump(copy))
  end

  def self.new_from_dump(status)
    frequencer = Marshal.load(Base64.decode64(status))

    values = frequencer.analysis
    # recreate the proc on the analysis hash
    frequencer.analysis = Hash.new { |h,k| h[k] = Hash.new {|h,k| h[k] = Array.new(2, 0)} }
    # reinsert the dumped values
    values.keys.each do |day|
      values[day].keys.each do |peer|
        frequencer.analysis[day][peer] = values[day][peer]
      end
    end

    return frequencer
  end


  def analyze_win(win)
    dmin = win.keys.min
    dmax = win.keys.max

    # extract the list of unique peers
    peers = win.values.collect {|s| s.keys}.flatten.to_set.to_a

    peers.each do |peer|
      # collect the number of occurrence
      # we only need to know how many days in the window contains a contact with peer
      contacts = win.select {|a,b| b[peer] != [0, 0] }.size

      # the mean of contacts over a single day
      frequency = contacts.to_f / @win_size

      # how many contacts ingress and egress?
      total_in = win.values.collect {|x| x[peer][0]}.inject(:+)
      total_out = win.values.collect {|x| x[peer][1]}.inject(:+)

      # calculate the factor of in both directions
      twfo = total_in > 0 ? total_out.to_f / total_in.to_f : 0
      twfi = total_out > 0 ? total_in.to_f / total_out.to_f : 0

      # adjust the frequency with the minimum between the factors
      # to eliminate spamming spikes
      score = frequency * [twfo, twfi].min
      density = (total_in + total_out) / @win_size

      if score >= @relevance #and density >= 1
        #puts "#{dmin} #{dmax} #{peer} freq: #{frequency} twfi: %.2f twfo: %.2f adj: %.2f  [#{total_in}, #{total_out}][#{contacts}]" % [twfi, twfo, score]
        yield peer
      end
    end
  end

  def analyze
    return if @analysis.size < @win_size + 1

    begin
      # take the first @win_size elements (skip the others)
      win = Hash[@analysis.sort_by{|k,v| k}.first @win_size]

      # analyze current window
      analyze_win(win) do |peer|
        yield peer
      end

      #cut the first one until window size
      @analysis.delete(@analysis.keys.min)
    end until @analysis.size != @win_size + 1
  end

  def fill_holes
    # make sure all the days are present
    (Date.parse(@analysis.keys.min)..Date.parse(@analysis.keys.max)).map do |date|
      day = date.strftime('%Y-%m-%d')
      # trick to really create the entry
      # the auto-initialization of the hash will do the rest
      @analysis[day] = @analysis[day]
    end
  end

  def insert_peer(date, peer, versus)
    index = (versus.eql? :in) ? 0 : 1
    @analysis[date][peer][index] += 1
  end

  def feed(time, peer, versus)
    raise "incorrect time format" unless time.is_a? Time
    date = time.strftime('%Y-%m-%d')

    # put the current peer in the analysis matrix
    insert_peer date, peer, versus

    # fill the holes in the matrix for the days without entries
    # if we have 20130101 and 20130104 we have to fill for 20130102 and 20130103
    fill_holes

    # perform analysis on the current matrix and yield a result if any
    analyze do |peer|
      yield peer
    end
  end

end

end
end
