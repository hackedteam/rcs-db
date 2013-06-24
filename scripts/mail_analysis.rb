require 'pp'
require 'date'
require 'set'

PEER = 'marchetti'

$analysis = Hash.new { |h,k| h[k] = Hash.new {|h,k| h[k] = Array.new(2, 0)} }
$total = Hash.new(0)
$peers = Set.new

MIN_FREQ = 0.35
WINDOW_SIZE = 10

def fill_holes
  # make sure the days are all present
  (Date.parse($analysis.keys.min)..Date.parse($analysis.keys.max)).map do |date| 
    day = date.strftime('%Y-%m-%d')
    $analysis[day] = $analysis[day]
  end
end

def analyze_win(win)
  #puts "win: #{win}"
  dmin = win.keys.min
  dmax = win.keys.max

  #exctract the list unique peers
  peers = win.values.collect {|s| s.keys}.flatten.to_set.to_a

  peers.each do |peer|
    # collect the number of occurrence
    # we only need to know how many days in the window contains a contact with peer
    contacts = win.select {|a,b| b[peer] != [0, 0] }.size
    frequency = contacts.to_f / WINDOW_SIZE

    total_in = win.values.collect {|x| x[peer][0]}.inject(:+)
    total_out = win.values.collect {|x| x[peer][1]}.inject(:+)

    twfo = total_in > 0 ? total_out.to_f / total_in.to_f : 0
    twfi = total_out > 0 ? total_in.to_f / total_out.to_f : 0
    
    adjusted = frequency * [twfo, twfi].min
    density = (total_in + total_out) / WINDOW_SIZE

    if adjusted >= MIN_FREQ #and density >= 1
      puts "#{dmin} #{dmax} #{peer} freq: #{frequency} twfi: %.2f twfo: %.2f adj: %.2f  [#{total_in}, #{total_out}][#{contacts}]" % [twfi, twfo, adjusted] 
        yield peer
    end
  end
  #exit
end

def analyze
  return if $analysis.size < WINDOW_SIZE + 1
  
  begin
    # take the first N elements
    win = Hash[$analysis.sort_by{|k,v| k}.first WINDOW_SIZE]

    # analyze current window
    analyze_win(win) do |peer|
      yield peer
    end
  
    #cut the first one until window size
    $analysis.delete($analysis.keys.min)
  end until $analysis.size != WINDOW_SIZE + 1
end

def frequencer(date, peer, versus)
  i = (versus.eql? :in) ? 0 : 1
  $analysis[date][peer][i] += 1
  fill_holes
  analyze do |peer|
    yield peer
  end
end


# load data from file
File.readlines('mail.txt').each do |line|
  date, versus, peer, from, to = line.split(' ')
  $total[peer] += 1
  #next unless peer.include? PEER
  frequencer(date, peer, versus.to_sym) do |peer|
    $peers << peer
  end
end

pp $peers.to_a
#pp $total.sort_by {|k,v| v}

