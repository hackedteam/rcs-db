require 'pp'
require 'date'

PEER = 'marchetti'

$analysis = Hash.new(0)
$total = Hash.new(0)

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

  contacts = win.select {|a,b| b > 0 }.size
  frequency = contacts.to_f / WINDOW_SIZE

  total = win.each_value.inject(:+)
  density = total * frequency
  puts "#{dmin} #{dmax} freq: #{frequency} dens: %.2f" % density
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
  $analysis[date] += 1
  fill_holes
  analyze
end


# load data from file
File.readlines('mail.txt').each do |line|
  date, versus, peer, from, to = line.split(' ')
  $total[peer] += 1
  next unless peer.include? PEER
  frequencer(date, peer)
end


#(Date.parse($analysis.keys.min)..Date.parse($analysis.keys.max)).map do |date| 
#  day = date.strftime('%Y-%m-%d')
#  #puts "#{day} #{$analysis[day]}"
#  $analysis[day] = $analysis[day]
#end

#pp $total.sort_by {|k,v| v}