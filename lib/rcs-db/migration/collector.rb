require_relative '../db_layer'

module RCS
module DB

class CollectorMigration
  extend Tracer
  
  def self.migrate(verbose)
  
    print "Migrating collectors "

    collectors = DB.instance.mysql_query('SELECT * from `collector` ORDER BY `collector_id`;').to_a
    collectors.each do |collector|

      # skip item if already migrated
      next if Collector.count(conditions: {_mid: collector[:collector_id]}) != 0

      trace :info, "Migrating collector '#{collector[:collector]}'." if verbose
      print "." unless verbose
      
      mc = ::Collector.new
      mc[:_mid] = collector[:collector_id]
      mc.type = collector[:type].downcase
      mc.name = collector[:collector]
      mc.desc = collector[:desc]
      mc.address = collector[:address]
      mc.port = collector[:port]
      mc.poll = collector[:poll] == 0 ? false : true
      mc.instance = collector[:instance]
      mc.configured = collector[:status] == 0 ? false : true
      mc.version = collector[:version].to_i

      mc.prev = [nil]
      mc.next = [nil]
      
      mc.save
    end
    
    puts " done."
    
  end

  def self.migrate_topology(verbose)

    print "Relinking collectors' topology "

    collectors = DB.instance.mysql_query('SELECT * from `collector` ORDER BY `collector_id`;').to_a
    collectors.each do |collector|

      mc = Collector.where({_mid: collector[:collector_id]}).first

      mc_next = Collector.where({_mid: collector[:nexthop]}).first unless collector[:nexthop].nil?
      mc_prev = Collector.where({_mid: collector[:prevhop]}).first unless collector[:prevhop].nil?

      prev_id = mc_prev[:_id] unless mc_prev.nil?
      next_id = mc_next[:_id] unless mc_next.nil?

      # skip already connected collectors
      next if mc.next.include? next_id and mc.prev.include? prev_id

      print "." unless verbose

      mc.prev = [prev_id.to_s]
      mc.next = [next_id.to_s]

      mc.save
    end

    puts " done."
  end

end

end # ::DB
end # ::RCS
