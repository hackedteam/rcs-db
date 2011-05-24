require 'benchmark'
require '../lib/rcs-db/db_objects/audit'

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

Benchmark.bm do |x|
  x.report {
    100_000.times do |n|
      a = Audit.new
      a[:time] = Time.now.getutc.to_i
      a[:desc] = "This is the #{n}th audit log."
      a[:action] = ['user.create', 'auth.login'].sample
      a.save
    end
  }
end