require_relative '../db_layer'
require_relative '../grid'

module RCS
module DB

class InjectorMigration
  extend Tracer
  
  def self.migrate(verbose)
  
    print "Migrating injectors "

    proxies = DB.instance.mysql_query('SELECT * from `proxy` ORDER BY `proxy_id`;').to_a
    proxies.each do |proxy|

      # skip item if already migrated
      next if Injector.count(conditions: {_mid: proxy[:proxy_id]}) != 0

      trace :info, "Migrating injector '#{proxy[:proxy]}'." if verbose
      print "." unless verbose
      
      mi = ::Injector.new
      mi[:_mid] = proxy[:proxy_id]
      mi.name = proxy[:proxy]
      mi.desc = proxy[:desc]
      mi.address = proxy[:address]
      mi.redirect = proxy[:redirect]
      mi.port = proxy[:port]
      mi.poll = proxy[:poll] == 0 ? false : true
      mi.configured = proxy[:status] == 0 ? true : false
      mi.version = proxy[:version].to_i
      mi.redirection_tag = proxy[:tag]
      mi[:_grid] = []
      mi[:_grid_size] = 0

      mi.save
    end
    
    puts " done."
    
  end

  def self.migrate_rules(verbose)

    print "Migrating injector rules "

    rules = DB.instance.mysql_query('SELECT * from `proxyrule` ORDER BY `proxy_id`;').to_a
    rules.each do |rule|

      proxy = Injector.where({_mid: rule[:proxy_id]}).first
      target = Item.where({_mid: rule[:target_id], _kind: 'target'}).first

      # skip already migrated rules
      next unless proxy.rules.where({_mid: rule[:proxyrule_id]}).first.nil?

      mr = InjectorRule.new
      mr[:_mid] = rule[:proxyrule_id]
      mr.enabled = rule[:disabled] == 0 ? true : false
      mr.disable_sync = rule[:until_sync] == 0 ? false : true
      mr.probability = rule[:probability]

      mr.target_id = [ target[:_id] ]
      mr.ident = rule[:user_type]
      mr.ident_param = rule[:user_pattern]
      mr.resource = rule[:resource_pattern]
      mr.action = rule[:action_type]

      if mr.action == 'REPLACE'
        mr.action_param_name = rule[:action_param]
        mr[:_grid] = [ GridFS.put(rule[:content], {filename: rule[:action_param]}) ] if rule[:content].bytesize > 0
      else
        agent = ::Item.where({ident: rule[:action_param]}).first
        next if agent.nil?
        mr.action_param = agent._id
        mr.action_param_name = agent._id
      end

      print "." unless verbose

      proxy.rules << mr
    end

    puts " done."
  end

end

end # ::DB
end # ::RCS
