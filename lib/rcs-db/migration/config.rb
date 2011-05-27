require 'rcs-db/db_layer'
require 'xmlsimple'
require 'json'

module RCS
module DB

class ConfigMigration
  extend Tracer

  class << self

    def migrate(verbose)

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

        mc.config = xml_to_json(config[:content])

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

    def migrate_templates(verbose)

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

        mt.config = xml_to_json(template[:content])

        mt.save
      end

      puts " done."
    end

    def parse_globals(item)
      {}
    end

    def parse_events(item)
      []
    end

    def parse_actions(item)
      []
    end

    def parse_agents(item)
      []
    end

    def xml_to_json(content)
      #TODO: convert to JSON

      agents = []
      actions = []
      events = []
      globals = {}

      old_config = XmlSimple.xml_in(content)

      old_config.each do |section|
        case section[0]
          when 'globals'
            globals = parse_globals(section[1].first)
          when 'events'
            events = parse_events(section[1].first['event'])
          when 'actions'
            actions = parse_actions(section[1].first['action'])
          when 'agents'
            agents = parse_agents(section[1].first['agent'])
        end
      end

      config = {'agents' => agents, 'actions' => actions, 'events' => events, 'globals' => globals}

      return config.to_json
    end


  end
end

end # ::DB
end # ::RCS
