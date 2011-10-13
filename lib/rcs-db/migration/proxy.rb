require 'rcs-db/db_layer'
require_relative '../grid'

module RCS
module DB

class ProxyMigration
  extend Tracer
  
  def self.migrate(verbose)
  
    print "Migrating proxies "

    proxies = DB.instance.mysql_query('SELECT * from `proxy` ORDER BY `proxy_id`;').to_a
    proxies.each do |proxy|

      # skip item if already migrated
      next if Proxy.count(conditions: {_mid: proxy[:proxy_id]}) != 0

      trace :info, "Migrating proxy '#{proxy[:proxy]}'." if verbose
      print "." unless verbose
      
      mp = ::Proxy.new
      mp[:_mid] = proxy[:proxy_id]
      mp.name = proxy[:proxy]
      mp.desc = proxy[:desc]
      mp.address = proxy[:address]
      mp.redirect = proxy[:redirect]
      mp.port = proxy[:port]
      mp.poll = proxy[:poll] == 0 ? false : true
      mp.configured = proxy[:status] == 0 ? true : false
      mp.version = proxy[:version].to_i
      mp.redirection_tag = proxy[:tag]

      mp.save
    end
    
    puts " done."
    
  end

  def self.migrate_rules(verbose)

    print "Migrating proxy rules "

    rules = DB.instance.mysql_query('SELECT * from `proxyrule` ORDER BY `proxy_id`;').to_a
    rules.each do |rule|

      proxy = Proxy.where({_mid: rule[:proxy_id]}).first
      target = Item.where({_mid: rule[:target_id], _kind: 'target'}).first

      # skip already migrated rules
      next unless proxy.rules.where({_mid: rule[:proxyrule_id]}).first.nil?

      mr = ProxyRule.new
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
