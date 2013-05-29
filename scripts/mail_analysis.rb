require 'pp'
require 'date'
require 'set'

PEER = 'marchetti'

$analysis = Hash.new { |hash, key| hash[key] = Hash.new(0) }
$total = Hash.new(0)
$peers = Set.new

MIN_FREQ = 0.9
WINDOW_SIZE = 3

def fill_holes
  # make sure the days are all present
  (Date.parse($analysis.keys.min)..Date.parse($analysis.keys.max)).map do |date| 
    day = date.strftime('%Y-%m-%d')
    $analysis[day] = $analysis[day]
  end
end

def analyze_win(win)
  puts "win: #{win}"
  dmin = win.keys.min
  dmax = win.keys.max

  #exctract the list unique peers
  peers = win.values.collect {|s| s.keys}.flatten.to_set.to_a

  peers.each do |peer|
    # collect the number of occurrence
    # we only need to know how many days in the window contains a contact with peer
    contacts = win.select {|a,b| b.has_key? peer }.size
    frequency = contacts.to_f / WINDOW_SIZE

    total = win.values.collect {|x| x[peer]}.inject(:+)
    density = total * frequency
    if frequency >= MIN_FREQ
      puts "#{dmin} #{dmax} #{peer} freq: #{frequency} dens: %.2f" % density 
      $peers << peer
    end
  end
end

def analyze
  return if $analysis.size < WINDOW_SIZE
  
  begin
    # take the first N elements
    win = Hash[$analysis.sort_by{|k,v| k}.first WINDOW_SIZE]

    # analyze current window
    analyze_win win
  
    #cut the first one until window size
    $analysis.delete($analysis.keys.min)
  end until $analysis.size != WINDOW_SIZE
end

def frequencer(date, peer)
  $analysis[date][peer] += 1
  fill_holes
  analyze
end


# load data from file
File.readlines('mail.txt').each do |line|
  date, versus, peer, from, to = line.split(' ')
  $total[peer] += 1
  #next unless peer.include? PEER
  frequencer(date, peer)
end

pp $peers.to_a

#(Date.parse($analysis.keys.min)..Date.parse($analysis.keys.max)).map do |date| 
#  day = date.strftime('%Y-%m-%d')
#  #puts "#{day} #{$analysis[day]}"
#  $analysis[day] = $analysis[day]
#end

#pp $total.sort_by {|k,v| v}