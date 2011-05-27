require 'benchmark'
require_relative '../lib/rcs-db/audit'
require_relative '../lib/rcs-db/db_objects/audit'

# connect to MongoDB
begin
  Mongoid.load!(Dir.pwd + '/../config/mongoid.yaml')
  Mongoid.configure do |config|
    config.master = Mongo::Connection.new.db('rcs')
    #config.logger = Logger.new $stdout
  end
rescue Exception => e
  puts e
  exit
end

if false
  n_inserts = 100_000
end_time = Time.now.getutc
months = 12
insert_time = end_time - 2_592_000 * months
interval = (end_time - insert_time).to_i / n_inserts
Benchmark.bm do |x|
  x.report {
    n_inserts.times do |n|
      log = Hash.new
      insert_time += interval
      log[:time] = insert_time.to_i
      log[:user] = ['pippo', 'pluto', 'paperino', 'bart', 'jebediah', 'homer'].sample
      log[:desc] = ["This is the #{n}th audit log.", "Mob rules.", "paper rock scissors.", "there's no place like home.", "User 'jeff' logged in.", "Suck my sock!"].sample
      log[:action] = ['user.create', 'auth.login', 'user.update'].sample
      RCS::DB::Audit.log(log)
    end
  }
end
end

if false
  puts Audit.count(conditions: {desc: Regexp.new('rock', true)})
  puts Audit.where(desc: Regexp.new('rock', true))
end

if false
  puts Audit.count(conditions: {:time.gte => 1306317384, :time.lte => 1306317384})
  puts Audit.where(:time.gte => 1306317384, :time.lte => 1306317384)
end
