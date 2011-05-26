require 'rcs-db/db_layer'

module RCS
module DB

class ConfigMigration
  extend Tracer
  
  def self.migrate(verbose)
  
    print "Migrating backdoors' configurations "

    configs = DB.instance.mysql_query('SELECT * from `config` WHERE `backdoor_id` IS NOT NULL ORDER BY `config_id`;').to_a
    configs.each do |config|

      backdoor = Item.where({_mid: config[:backdoor_id]}).any_in(_kind: ['backdoor', 'factory']).first
      
      # skip item if already migrated
      next unless backdoor.configs.where({_mid: config[:config_id]}).first.nil?

      trace :info, "Migrating config  for '#{backdoor[:name]}'." if verbose

      mc = ::Configuration.new
      mc[:_mid] = config[:config_id]
      mc.desc = config[:desc]
      mc.user = config[:user]
      mc.saved = config[:saved].to_i
      mc.sent = config[:sent].to_i if config[:sent].to_i != 0
      
      #TODO: convert to JSON
      mc.config = config[:content]

      # migrate the complete config history
      if backdoor[:_kind] == 'backdoor'
        backdoor.configs << mc
        print "." unless verbose
      end

      # factories does not have history
      if backdoor[:_kind] == 'factory'
        backdoor.configs = [ mc ]
        print "." unless verbose
      end

      backdoor.save

    end
    
    puts " done."
    
  end

  def self.migrate_templates(verbose)

    print "Migrating configuration templates "

    templates = DB.instance.mysql_query('SELECT * from `config` WHERE `backdoor_id` IS NULL ORDER BY `config_id`;').to_a
    templates.each do |template|

      # skip item if already migrated
      next if Template.count(conditions: {_mid: template[:config_id]}) != 0

      trace :info, "Migrating template '#{template[:desc]}'." if verbose
      print "." unless verbose

      mt = ::Template.new
      mt[:_mid] = template[:config_id]
      mt.desc = template[:desc]
      mt.user = template[:user]

      #TODO: convert to JSON
      mt.config = template[:content]
      
      mt.save
    end

    puts " done."
  end

end

end # ::DB
end # ::RCS
