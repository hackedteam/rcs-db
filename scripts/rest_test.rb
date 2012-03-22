require 'net/http'
require 'yajl/json_gem'
require 'benchmark'
require 'open-uri'
require 'pp'
require 'cgi'

class CGI
  def self.encode_query(hash)
    return hash.map{|k,v| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}"}.join("&")
  end
end

#http = Net::HTTP.new('localhost', 443)
http = Net::HTTP.new('localhost', 4444)
http.use_ssl = true
http.verify_mode = OpenSSL::SSL::VERIFY_NONE

# auth create admin
#account = {
#  :pass => 'adminp123'
#  }
#resp = http.request_post('/auth/reset', account.to_json, nil)
#puts "auth.create"
#puts resp.body

# login
account = {
  :user => 'daniele', 
  :pass => 'danielep123'
  }
resp = http.request_post('/auth/login', account.to_json, nil)
puts "auth.login"
puts resp
cookie = resp['Set-Cookie'] unless resp['Set-Cookie'].nil?
puts "cookie " + cookie
puts

# session
if false
  # session.index
  res = http.request_get('/session', {'Cookie' => cookie})
  puts "session.index"
  puts res
  puts
  
  sess = JSON.parse(res.body)[0]
  
  # session.destroy
  res = http.delete("/session/#{sess['cookie']}", {'Cookie' => cookie})
  puts "session.destroy"
  puts res
  puts
end

# user
if false 
# user.create
# {'name': 'admin', 'pass': '6104a8be02be972bedf8c8bf107370fc517e2606', 'desc': 'Deus Ex Machina', 'contact': '', 'privs': ['ADMIN', 'TECH', 'VIEW'], 'enabled': true, 'locale': 'en_US', 'timezone': 0, 'group_ids':[]}
user = {'name' => 'testina', 'pass' => 'test', 'desc' => 'Deus Ex Machina', 'contact' => '', 'privs' => ['ADMIN', 'TECH', 'VIEW'], 'enabled' => true, 'locale' => 'en_US', 'timezone' => 0}
res = http.request_post('/user', user.to_json, {'Cookie' => cookie}) 
puts "user.create "
puts res
puts

exit unless res.kind_of? Net::HTTPOK

test_user = JSON.parse(res.body)

#user.index
res = http.request_get('/user', {'Cookie' => cookie})
puts "user.index"
puts res
puts

# user.update
user = {'desc' => 'Fallen angel', 'contact' => 'billg@microsoft.com', 'not_exist' => 'invalid field'}
res = http.request_put("/user/#{test_user['_id']}", user.to_json, {'Cookie' => cookie}) 
puts "user.update "
puts res
puts

#user.show
res = http.request_get("/user/#{test_user['_id']}", {'Cookie' => cookie})
puts "user.show"
puts res
puts

# user.destroy
#res = http.delete("/user/#{test_user['_id']}", {'Cookie' => cookie}) 
#puts "user.delete "
#puts res
#puts

end

# group
if false
# group.create
group = {'name' => 'test'}
res = http.request_post('/group', group.to_json, {'Cookie' => cookie}) 
puts "group.create "
puts res
puts

exit unless res.kind_of? Net::HTTPOK

test_group = JSON.parse(res.body)

# group.index
res = http.request_get('/group', {'Cookie' => cookie})
puts "group.index"
puts res
puts

# group.alert
group = {'name' => 'test container'}
res = http.request_post("/group/alert", test_group['_id'].to_json, {'Cookie' => cookie}) 
puts "group.alert "
puts res
puts

# group.update
group = {'name' => 'test container'}
res = http.request_put("/group/#{test_group['_id']}", group.to_json, {'Cookie' => cookie}) 
puts "group.update "
puts res
puts

# get the first user
res = http.request_get('/user', {'Cookie' => cookie})
test_user = JSON.parse(res.body)[0]

# group.add_user
group_user = {user: {_id: test_user['_id']}}
res = http.request_post("/group/add_user/#{test_group['_id']}", group_user.to_json, {'Cookie' => cookie}) 
puts "group.add_user "
puts res
puts

# get the first user
res = http.request_get('/user', {'Cookie' => cookie})
test_user = JSON.parse(res.body)[0]
puts "relation inside user?"
puts test_user.inspect
puts

# group.show
res = http.request_get("/group/#{test_group['_id']}", {'Cookie' => cookie})
puts "group.show"
puts res
puts

# group.del_user
group_user = {user: {_id: test_user['_id']}}
res = http.request_post("/group/del_user/#{test_group['_id']}", group_user.to_json, {'Cookie' => cookie}) 
puts "group.del_user "
puts res
puts

# group.show
res = http.request_get("/group/#{test_group['_id']}", {'Cookie' => cookie})
puts "group.show"
puts res
puts

# get the first user
res = http.request_get('/user', {'Cookie' => cookie})
test_user = JSON.parse(res.body)[0]
puts "Is the user still there?"
puts test_user.inspect
puts

# group.destroy
res = http.delete("/group/#{test_group['_id']}", {'Cookie' => cookie}) 
puts "group.delete "
puts res
puts

# get the first user
res = http.request_get('/user', {'Cookie' => cookie})
test_user = JSON.parse(res.body)[0]
puts "Is the user still there?"
puts test_user.inspect
puts

end

# audit
if false
  # audit.count
    res = http.request_get('/audit/filters', {'Cookie' => cookie})
    puts "audit.filters"
    puts res.body
    puts
  
   res = http.request_get('/audit/count', {'Cookie' => cookie})
   puts "audit.count"
   puts res.body.inspect
   puts
   
   res = http.request_get(URI.escape('/audit/count?filter={"action": ["puddu"]}'), {'Cookie' => cookie})
   puts "audit.count 'puddu'"
   puts res.body.inspect
   puts
   
   res = http.request_get(URI.escape('/audit/count?filter={"action": ["user.update", "login"]}'), {'Cookie' => cookie})
   puts "audit.count 'user.update'"
   puts res.body.inspect
   puts
   
  # audit.index
   res = http.request_get(URI.escape('/audit?filter={"action": ["user.update"]}&startIndex=0&numItems=10'), {'Cookie' => cookie})
   puts "audit.index 'user.update'"
   puts res
   puts
   
   # audit.index
  res = http.request_get('/audit', {'Cookie' => cookie})
  puts "audit.index"
  puts res
  puts
end

# audit export log
if false
  params = {'file_name' => 'pippo', 'filter' => {"action" => ["user.update", "login"]} }
  res = http.request_post("/audit/create", params.to_json, {'Cookie' => cookie})
  puts "audit.export"
  File.open('pippo.csv', 'wb') do |f|
    f.write res.body
  end
  puts
end

# license
if false
  # license.limit
  res = http.request_get('/license/limit', {'Cookie' => cookie})
  puts "license.limit"
  puts res.body
  puts
  
  # license.count
  res = http.request_get('/license/count', {'Cookie' => cookie})
  puts "license.count"
  puts res.body
  puts
end

# monitor
if false
  # status.index
  res = http.request_get('/status', {'Cookie' => cookie})
  puts "status.index"
  puts res
  puts res.body
  
  #monitor = JSON.parse(res.body)[0]
  
  #res = http.delete("/status/#{monitor['_id']}", {'Cookie' => cookie})
  #puts "status.destroy"
  #puts res
  #puts

  res = http.request_get('/status/counters', {'Cookie' => cookie})
  puts "status.counters"
  puts res
  puts
end

# task
if false

def REST_task(http, cookie, type, filename, params={})
  
  task_params = {'type' => type, 'file_name' => filename}
  task_params.merge! params
  
  res = http.request_post('/task/create', task_params.to_json, {'Cookie' => cookie})
  res.kind_of? Net::HTTPSuccess or fail("Cannot create task.")
  puts res.body
  task = JSON.parse(res.body)
  puts "Created task #{task['_id']}"
  puts "TASK STATUS: #{task['status']}"
  puts
  
  while (task['status'] != 'download_available' and not task['status'] == 'finished')
    res = http.request_get("/task/#{task['_id']}", {'Cookie' => cookie})
    puts res.body
    task = JSON.parse(res.body)
    puts "#{task['current']}/#{task['total']} #{task['description']}"
    break if task['error'] == true
    resource = task['resource']
    sleep 0.05
  end
  
  puts "TASK STATUS: #{task['status']}"
  puts "#{task['current']}/#{task['total']} #{task['desc']}"
  
  unless resource.nil?
    puts "resource: #{resource.to_s}"
    res = http.request_get("/file/#{resource['_id']}", {'Cookie' => cookie})
    puts "#{resource['type']}.get"
    File.open(resource['file_name'], 'wb') do |f|
    f.write res.body
  end
    puts "Written #{resource['file_name']} (#{File.size(resource['file_name'])})."
  end
  
  puts "Deleting task #{task['_id'].to_json}."
  res = http.request_post('/task/destroy', {_id: task['_id']}.to_json, {'Cookie' => cookie})
  puts res.inspect
  puts
end

#REST_task(http, cookie, 'audit', 'audit-all.tar.gz')
#REST_task(http, cookie, 'dummy', 'dummy.tar.gz')

res = http.request_get('/factory', {'Cookie' => cookie})
factories = JSON.parse(res.body)

android_params = {params: {factory: {_id: factories.first['_id']},
                  platform: 'android',
                  binary: {demo: true},
                  melt: {appname: 'facebook'}
                  }
                }
bb_params =  {params: {factory: {_id: factories.first['_id']},
                platform: 'blackberry',
                binary: {demo: true},
                melt: {appname: 'facebook',
                  name: 'Facebook Application',
                  desc: 'Applicazione utilissima di social network',
                  vendor: 'face inc',
                  version: '1.2.3'},
                package: {type: 'remote'}
                }
              }
              
wap_params = {params: {factory: {_id: factories.first['_id']},
                platform: 'wap',
                        generate: {platforms: ['blackberry', 'android', 'winmo'],
                                   binary: {demo: true, admin: true},
                                   melt: {admin: true,
                                          appname: 'facebook',
                                          name: 'Facebook Application',
                                          desc: 'Applicazione utilissima di social network',
                                          vendor: 'face inc',
                                          version: '1.2.3'},
                                   sign: {edition: '5th3rd'}
                                  }
                        }
              }
              
nia_params = {params: {injector_id: '4ef0542e963d350d8800115e'}}
                                   
#REST_task(http, cookie, 'build', 'android.zip', android_params)
#REST_task(http, cookie, 'build', 'bb.zip', bb_params)
#REST_task(http, cookie, 'build', nil, wap_params)
REST_task(http, cookie, 'injector', nil, nia_params)

=begin
sleep 3

res = http.delete("/task/#{task['id']}", {'Cookie' => cookie})
puts "task.delete"
puts res
puts
=end

end # task

# grid
if false
=begin
  grid_id = '4dfa1d1aa4df496c90fab43e' # 1.4 gb (underground.avi)
  #grid_id = '4dfa2483674bba48cd2a153f' # 280 mb (en_outlook.exe)
  fo = File.open('underground.avi', 'wb')
  puts "grid.show"
  total = 0
  http.request_get("/grid/#{grid_id}", {'Cookie' => cookie}) do |resp|
    resp.read_body do |segment|
      print "."
      total += segment.bytesize
      fo.write(segment)
    end
  end
  fo.close
  puts "Got #{total} bytes."
=end

  fo = File.open('dropall.js', 'rb') do |f|
    ret = http.request_post("/grid", f.read ,{'Cookie' => cookie})
    puts ret
  end
end

# injector
if false
  
  injector_id = 0
  
  # injector.index
  #res = http.request_get('/injector', {'Cookie' => cookie})
  #puts "injector.index"
  #puts res.body
  #puts
  
  #injectors = JSON.parse(res.body)
  #injectors.each do |injector|
  #  if injector['_mid'] == 3
  #    injector_id = injector['_id']
  #  end
  #end
  
  # injector.delete
  #injectors.each do |injector|
  #  puts "injector.delete"
  #  ret = http.delete("/injector/#{injector['_id']}", {'Cookie' => cookie})
  #  puts ret
  #end
  
  # injector.create
  injector = {name: 'test'}
  res = http.request_post('/injector', injector.to_json, {'Cookie' => cookie})
  puts "injector.create"
  puts res
  puts
  
  test_injector = JSON.parse(res.body)
  injector_id = test_injector['_id']
  
  # injector.update
  injector = {name: 'NIA', address: '1.2.3.4', redirect: '4.3.2.1', desc: 'test injection injector', port: 4445, poll: true}
  res = http.request_put("/injector/#{injector_id}", injector.to_json, {'Cookie' => cookie}) 
  puts "injector.update "
  puts res
  puts
  
  # injector.show
  res = http.request_get("/injector/#{injector_id}", {'Cookie' => cookie})
  puts "injector.show"
  puts res.body
  #injector = JSON.parse(res.body)
  #puts injector.inspect
  puts
  
  # injector.rules
  puts "injector.rules"
  puts injector['rules'].inspect
  puts
  
  # injector.log
  res = http.request_get("/injector/logs/#{injector_id}", {'Cookie' => cookie})
  puts "injector.log"
  puts res
  puts
  
  # injector.add_rule
  puts "injector.add_rule"
  rule = {rule: {enabled: true, disable_sync: false, ident: 'STATIC-IP', 
          ident_param: '14.11.78.4', probability: 100, resource: 'www.alor.it', 
          action: 'INJECT-HTML', action_param: 'RCS_0000602', target_id: ['4e314a052afb65157900005a']}}
  res = http.request_post("/injector/add_rule/#{injector_id}", rule.to_json, {'Cookie' => cookie})

  rule = JSON.parse(res.body)
  puts rule
  puts
  
  # injector.rules
  puts "injector.show"
  res = http.request_get("/injector/#{injector_id}", {'Cookie' => cookie})
  puts res.body
  injector = JSON.parse(res.body)
  #puts injector['rules'].inspect
  puts
  
  # upload.create
  res = http.request_post('/upload', "abracadabra", {'Cookie' => cookie})
  puts "upload.create"
  puts res.body
  puts
  
  upload_id = res.body
  
  # injector.update_rule
  puts "injector.update_rule"
  mod = {rule: {_id: rule['_id'], enabled: false, disable_sync: true, ident: 'STATIC-MAC',
          ident_param: '00:11:22:33:44:55', target_id: ['4e314a052afb65157900005a'], action: 'REPLACE', action_param: upload_id}}
  res = http.request_post("/injector/update_rule/#{injector_id}", mod.to_json, {'Cookie' => cookie})
  puts res
  puts
  
  # injector.rules
  puts "injector.show"
  res = http.request_get("/injector/#{injector_id}", {'Cookie' => cookie})
  puts res.body
  #injector = JSON.parse(res.body)
  #puts injector['rules'].inspect
  puts
  
  # injector.del_rule
  puts "injector.del_rule"
  request = {rule: {_id: rule['_id']}}
  res = http.request_post("/injector/del_rule/#{injector_id}", request.to_json, {'Cookie' => cookie})
  puts res
  puts
  
  # injector.config
  puts "injector.config"
  res = http.request_get("/injector/config/#{injector_id}", {'Cookie' => cookie})
  puts res
  puts

  # injector.delete
  puts "injector.delete"
  ret = http.delete("/injector/#{injector_id}", {'Cookie' => cookie})
  puts ret
  
  
  
end

# injector config
if false
  
  # injector.config
  res = http.request_get("/injector/config/4e9ec80d2afb657230001012", {'Cookie' => cookie})
  puts "injector.config"
  puts res.body
  
  File.open('config.zip', 'wb+') do |f|
    f.write res.body
  end

  puts "File saved (#{res.body.size})"

end

# collector
if false
  # collector.index
  #res = http.request_get('/collector', {'Cookie' => cookie})
  #puts "collector.index"
  #puts res.body
  
  
  coll = {_id: '4f34cea32afb6552150012ac'}
  res = http.request_get('/collector/config/4f34cea32afb6552150012ac', {'Cookie' => cookie})
  puts "collector.config"
  puts res
  puts
  
  #File.open('conf.zip', 'wb') {|f| f.write res.body}
  
=begin  
  collectors = JSON.parse(res.body)
  collectors.each do |coll|
    puts coll
    puts
  end
  
  # collector.delete
  collectors.each do |coll|
    puts "collector.delete"
    ret = http.delete("/collector/#{coll['_id']}", {'Cookie' => cookie})
    puts ret
  end

  # collector.create
  coll = {name: 'test'}
  res = http.request_post('/collector', coll.to_json, {'Cookie' => cookie})
  puts "collector.create"
  puts res
  puts
  
  test_coll = JSON.parse(res.body)
  
  # collector.update
  coll = {name: 'anonymizer', address: '1.2.3.4', desc: 'test collector', port: 4445, poll: true}
  res = http.request_put("/collector/#{test_coll['_id']}", coll.to_json, {'Cookie' => cookie}) 
  puts "collector.update "
  puts res
  puts
=end    
end

# alerts
if false
  # alert.index
  puts "alert.index" 
  res = http.request_get('/alert', {'Cookie' => cookie})
  puts res
  puts
  
  # alert.create
  puts "alert.create" 
  alert = {evidence: 'keylog', priority: 5, suppression: 600, type: 'mail', keywords: 'ciao miao bau', path: [1, 2, 3]}
  res = http.request_post('/alert', alert.to_json, {'Cookie' => cookie})
  alert = JSON.parse(res.body)
  puts alert
  puts

  # alert.index
  puts "alert.index" 
  res = http.request_get('/alert', {'Cookie' => cookie})
  puts res
  puts

  # alert.update
  puts "alert.update" 
  mod = {evidence: 'chat', priority: 1, enabled: false}
  res = http.request_put("/alert/#{alert['_id']}", mod.to_json, {'Cookie' => cookie})
  puts res
  puts

  # alert.show
  puts "alert.show" 
  res = http.request_get("/alert/#{alert['_id']}", {'Cookie' => cookie})
  puts res
  puts
  
  # alert.index
  puts "alert.index" 
  res = http.request_get('/alert', {'Cookie' => cookie})
  puts res
  puts
  
  # alert.delete
  puts "alert.delete"
  res = http.delete("/alert/#{alert['_id']}", {'Cookie' => cookie})
  puts res
  puts
  
  # alert.index
  puts "alert.index" 
  res = http.request_get('/alert', {'Cookie' => cookie})
  puts res
  puts
  
  # alert.counter
  puts "alert.counter" 
  res = http.request_get('/alert/counters', {'Cookie' => cookie})
  puts res
  puts
  
end

# operations
if false
  puts "operation.index" 
  res = http.request_get('/operation', {'Cookie' => cookie})
  #puts res.body
  operations = JSON.parse(res.body)
  puts operations
  puts
  
  puts "operation.show"
  res = http.request_get("/operation/#{operations.first['_id']}", {'Cookie' => cookie})
  operation = JSON.parse(res.body)
  puts operation
  puts 
  
  #puts "operation.create"
  #operation_post = {
  #  name: "test operation", 
  #  desc: "this is a test operation", 
  #  contact: "billg@microsoft.com"
  #}
  #res = http.request_post("/operation/create", operation_post.to_json, {'Cookie' => cookie})
  #puts res.body
  #operation = JSON.parse(res.body)
  #puts operation
  #puts

  # group.show
  #res = http.request_get("/group/4e8ac48b2afb65289500000b", {'Cookie' => cookie})
  #puts "group.show"
  #puts res
  #puts
  
  #puts "operation.update"
  #operation_post = {
  #  _id: operation['_id'],
  #  name: "RENAMED!!!", 
  #  desc: "whoa! this is our renamed operation", 
  #  contact: "ballmer@microsoft.com",
  #  group_ids: ['4e8ac4612afb652936000006']
  #}
  #res = http.request_post("/operation/update", operation_post.to_json, {'Cookie' => cookie})
  #puts res.body
  #operation = JSON.parse(res.body)
  #puts operation
  #puts
  
  # group.show
  #res = http.request_get("/group/4e8ac48b2afb65289500000b", {'Cookie' => cookie})
  #puts "group.show"
  #puts res
  #puts
  
  #puts "operation.delete"
  #res = http.request_post("/operation/destroy", {_id: operation['_id']}.to_json, {'Cookie' => cookie})
  #puts res.body
  #puts
  
  # group.show
  #res = http.request_get("/group/4e8ac48b2afb65289500000b", {'Cookie' => cookie})
  #puts "group.show"
  #puts res
  #puts
end

# targets
if false
  res = http.request_get('/operation', {'Cookie' => cookie})
  operations = JSON.parse(res.body)

  puts "target.index" 
  res = http.request_get('/target', {'Cookie' => cookie})
  #puts res.body
  targets = JSON.parse(res.body)
  puts targets  
  puts

  puts "target.show"
  res = http.request_get("/target/#{targets.first['_id']}", {'Cookie' => cookie})
  #puts res.body
  target = JSON.parse(res.body)
  puts target
  puts

=begin  
  puts "target.create"
  target_post = {
    name: "test target", 
    desc: "this is a test target",
    operation: operations.first['_id']
  }
  res = http.request_post("/target/create", target_post.to_json, {'Cookie' => cookie})
  puts res.body
  target = JSON.parse(res.body)
  #puts target
  puts
  
  puts "target.update"
  target_post = {
    _id: target['_id'],
    name: "RENAMED!!!", 
    desc: "whoa! this is our renamed target", 
    contact: "ballmer@microsoft.com"
  }
  res = http.request_post("/target/update", target_post.to_json, {'Cookie' => cookie})
  puts res.body
  target = JSON.parse(res.body)
  #puts target
  puts
  
  puts "target.delete"
  res = http.request_post("/target/destroy", {_id: target['_id']}.to_json, {'Cookie' => cookie})
  puts res.body
  puts
=end
end

# agents
if false
=begin
  res = http.request_get('/operation', {'Cookie' => cookie})
  operations = JSON.parse(res.body)
  
  res = http.request_get('/target', {'Cookie' => cookie})
  targets = JSON.parse(res.body)
  
  puts "agent.index"
  res = http.request_get('/agent', {'Cookie' => cookie})
  agents = JSON.parse(res.body)
  #puts agents
  #agents.each {|agent| puts "#{agent['_kind']}\t#{agent['name']}"}
  puts "You got #{agents.size} agents."
  puts
=end
  
  puts "agent.show"
  res = http.request_get("/agent/4F6059012AFB65C9440000CC", {'Cookie' => cookie})
  puts res.body
  #agent = JSON.parse(res.body)
  #puts agent
  puts
  
  #puts "agent.filesystem POST"
  #filesystem_post = {
  #   _id: agent['_id'],
  #   filesystem: {path: '%HOMEDRIVE%\\\\*', depth: 2}
  # }
  #res = http.request_post("/agent/filesystem", filesystem_post.to_json, {'Cookie' => cookie})
  #fs_post = JSON.parse(res.body)
  #puts fs_post
  #puts
  
=begin
  puts "agent.update"
  agent_post = {
     _id: agent['_id'],
     name: "RENAMED!!!", 
     desc: "whoa! this is our renamed agent", 
     ident: "this field MUST NOT be updated!!!!!!!!!!!!"
   }
  res = http.request_post("/agent/update", agent_post.to_json, {'Cookie' => cookie})
  puts res.body
  agent = JSON.parse(res.body)
  puts agent
  puts
  
  puts "agent.add_config"
  agent_post = {
    _id: agent['_id'],
    config: "{active: true}"
  }
  res = http.request_post("/agent/add_config", agent_post.to_json, {'Cookie' => cookie})
  puts res.body
  config = JSON.parse(res.body)
  puts config['config']
  puts
  
  puts "agent.del_config"
  agent_post = {
    _id: agent['_id'],
    config_id: config['_id']
  }
  res = http.request_post("/agent/del_config", agent_post.to_json, {'Cookie' => cookie})
  puts res.body
  puts
  
  puts "agent.delete"
  res = http.request_post("/agent/destroy", {_id: agent['_id']}.to_json, {'Cookie' => cookie})
  puts res.body
  puts
=end
end

# factories
if false
  res = http.request_get('/operation', {'Cookie' => cookie})
  operations = JSON.parse(res.body)
  
  res = http.request_get('/target', {'Cookie' => cookie})
  targets = JSON.parse(res.body)
  
  puts "factory.index"
  res = http.request_get('/factory', {'Cookie' => cookie})
  #puts res.body
  factories = JSON.parse(res.body)
  puts factories
  puts "You got #{factories.size} factories."
  puts
  
  puts "factory.show"
  res = http.request_get("/factory/#{factories.first['_id']}", {'Cookie' => cookie})
  #puts res.body
  factory = JSON.parse(res.body)
  puts factory
  puts

=begin
  puts "factory.create"
  factory_post = {
     name: "Uber Factory!",
     desc: "The best factory in the World!",
     operation: targets.first['path'].first,
     target: targets.first['_id']
   }
  res = http.request_post("/factory/create", factory_post.to_json, {'Cookie' => cookie})
  puts res.body
  factory = JSON.parse(res.body)
  puts
  
  puts "factory.update"
  agent_post = {
     _id: factory['_id'],
     name: "RENAMED!!!", 
     desc: "whoa! this is our renamed factory", 
     ident: "this field MUST NOT be updated!!!!!!!!!!!!"
   }
  res = http.request_post("/factory/update", agent_post.to_json, {'Cookie' => cookie})
  puts res.body
  factory = JSON.parse(res.body)
  puts factory
  puts
  
  puts "factory.add_config"
  agent_post = {
    _id: factory['_id'],
    config: "{active: true}"
  }
  res = http.request_post("/factory/add_config", agent_post.to_json, {'Cookie' => cookie})
  puts res.body
  config = JSON.parse(res.body)
  puts config['config']
  puts
  
  puts "factory.del_config"
  agent_post = {
    _id: factory['_id'],
    config_id: config['_id']
  }
  res = http.request_post("/factory/del_config", agent_post.to_json, {'Cookie' => cookie})
  puts res.body
  puts
  
  puts "factory.delete"
  res = http.request_post("/factory/destroy", {_id: factory['_id']}.to_json, {'Cookie' => cookie})
  puts res.body
  puts
=end
end

# search
if false
  # search.index
  puts "search.index" 
  res = http.request_get('/search', {'Cookie' => cookie})
  items = JSON.parse(res.body)
  puts "You've got #{items.size} items."
  puts
  
  # search.index with filter
  puts "search.index RCS_0000000610"
  res = http.request_get(URI.escape('/search?filter={"name": "RCS_0000000610"}'), {'Cookie' => cookie})
  rcs_10 = JSON.parse(res.body)
  puts rcs_10
  puts
  
  puts "search.show"
  res = http.request_get("/search/#{rcs_10[0]["_id"]}", {'Cookie' => cookie})
  puts res.body
  puts
end

# upload
if false
  # upload.create
  res = http.request_post('/upload', "abracadabra", {'Cookie' => cookie})
  puts "upload.create"
  puts res
  puts
end

# version
if false
  # version.index
  puts "version.index" 
  res = http.request_get('/version', {'Cookie' => cookie})
  versions = JSON.parse(res.body)
  puts versions
  puts
  
  # version.show
  puts "version.show" 
  res = http.request_get("/version/#{versions['console']}", {'Cookie' => cookie})
  puts res
  puts
  
  
end

# shards
if false
  # shard.index
  puts "shard.index" 
  res = http.request_get('/shard', {'Cookie' => cookie})
  shards = JSON.parse(res.body)
  puts res.body
  puts
  
  shards['shards'].each do |shard|
    puts 'shard.show ' + shard['host']
    res = http.request_get("/shard/#{shard['_id']}", {'Cookie' => cookie})
    puts res.body
    puts
  end

  # shard.create
  #res = http.request_post('/shard/create', {host: "localhost:27027"}.to_json, {'Cookie' => cookie})
  #puts "shard.create"
  #puts res
  #puts
  
  # shard.index
  #puts "shard.index" 
  #res = http.request_get('/shard', {'Cookie' => cookie})
  #puts res.body
  #puts
end

# backup
if false
  # backup.index
  puts "backup.index" 
  res = http.request_get('/backupjob', {'Cookie' => cookie})
  shards = JSON.parse(res.body)
  puts res.body
  puts
  
  # backup.create
  #backup = {what: 'operation: 4e80369d2afb6509cc000026', enabled: true, when: {week: [], month: [], time: '09:20'}, name: 'ALoR Test'}
  #res = http.request_post('/backupjob/create', backup.to_json, {'Cookie' => cookie})
  #puts "backup.create"
  #puts res.body
  #puts
  
  #id = JSON.parse(res.body)['_id']
  
  # backup.delete
  #puts "backup.delete"
  #res = http.delete("/backup/#{id}", {'Cookie' => cookie})
  #puts res
  #puts
  
  # backuparchive.index
  puts "backuparchive.index" 
  res = http.request_get('/backuparchive', {'Cookie' => cookie})
  puts res.body
  puts
  
  # backuparchive.delete
  #puts "backuparchive.delete" 
  #res = http.delete('/backuparchive/metadata-2011-09-26-15:30', {'Cookie' => cookie})
  #puts res.body
  #puts

  # backuparchive.restore
  #puts "backuparchive.restore" 
  #res = http.request_post('/backuparchive/restore', {_id: 'metadata-2011-09-26-11:03'}.to_json, {'Cookie' => cookie})
  #puts res.body
  #puts
  
  
end
  
# evidence
if false
  # evidence.index
  #filter = {target: '4f28003c2afb65cf4700006c'}.to_json
  #res = http.request_get(URI.escape("/evidence?filter=#{filter}&startIndex=0&numItems=20"), {'Cookie' => cookie})
  #puts "evidence.index"
  #puts res.body
  #puts
  
  # evidence.index
  #filter = {target: '4ea526392afb656f0600003e', agent: '4ea526392afb656f06000133', type: ['keylog']}.to_json
  #res = http.request_get(URI.escape("/evidence?filter=#{filter}&startIndex=0&numItems=10"), {'Cookie' => cookie})
  #puts "evidence.index"
  #puts res
  #puts

  # evidence.total
  filter = {target: '4F44F5CA2AFB65935200006E', agent: '4f57169a2afb6519d4000009'}.to_json
  res = http.request_get(URI.escape("/evidence/total?filter=#{filter}"), {'Cookie' => cookie})
  puts "evidence.index"
  puts res.body
  puts
  
end
    
# config    
if false
  
  puts "agent.add_config"
  agent_post = {
    _id: '4ea526392afb656f06000097',
    desc: "nuova config via rest",
    config: "{active: true}"
  }
  res = http.request_post("/agent/add_config", agent_post.to_json, {'Cookie' => cookie})
  puts res.body
  config = JSON.parse(res.body)
  puts config['config']
  puts
  
  puts "agent.show"
  res = http.request_get("/agent/4ea526392afb656f06000097", {'Cookie' => cookie})
  puts res.body
  puts
  
end

# exploit
if false
  # exploit.index
  puts "exploit.index" 
  res = http.request_get('/exploit', {'Cookie' => cookie})
  shards = JSON.parse(res.body)
  puts res.body
  puts
end

# item deletion
if false
  puts "operation.create"
  operation_post = {
    name: "test operation", 
    desc: "this is a test operation", 
    contact: "billg@microsoft.com"
  }
  res = http.request_post("/operation/create", operation_post.to_json, {'Cookie' => cookie})
  operation = JSON.parse(res.body)
  puts operation
  puts
  
  res = http.request_get('/user', {'Cookie' => cookie})
  puts "user.index"
  users = JSON.parse(res.body)
  user = users.first
  puts user

  puts "user.add_recent"  
  res = http.request_post('/user/add_recent', {_id: user['_id'], item_id: operation['_id']}.to_json, {'Cookie' => cookie})

  res = http.request_get('/user', {'Cookie' => cookie})
  users = JSON.parse(res.body)
  user = users.first
  puts user

  puts "operation.delete"
  res = http.request_post("/operation/destroy", {_id: operation['_id']}.to_json, {'Cookie' => cookie})
  puts res.body
  puts

  puts "user.index"
  res = http.request_get('/user', {'Cookie' => cookie})
  users = JSON.parse(res.body)
  user = users.first
  puts user
  
end

#location
if false
  # GPS
  loc = {map: {location: {latitude: 45.12345, longitude: 9.54321}}}
  puts 'location.gps'
  res = http.request_post('/location', loc.to_json, {'Cookie' => cookie})
  puts res.body

  # CELL
  loc = {map: {cell_towers: [{mobile_country_code: 222, mobile_network_code: 1, location_area_code: 61208, cell_id: 528, signal_strength: -92, timing_advance: 0, age: 0}
                            ], radio_type: 'gsm'}}
  puts 'location.cell'
  res = http.request_post('/location', loc.to_json, {'Cookie' => cookie})
  puts res.body
  
  # WIFI
  loc = {map: {wifi_towers: [{mac_address: '00:17:C2:F8:9C:60', signal_strength: 55, ssid: 'FASTWEB-1-0017C2F89C60'},
          {mac_address: '00:25:C9:DF:AB:A7', signal_strength: 41, ssid: 'ht-guest-wifi'},
          {mac_address: '38:22:9D:F7:84:F4', signal_strength: 77, ssid: 'FASTWEB-1-38229DF784F4'},
          {mac_address: '00:1F:33:FC:B4:18', signal_strength: 85, ssid: 'NETGEAR'},
          {mac_address: '00:24:89:01:5E:0B', signal_strength: 48, ssid: 'Vodafone-10369386'},
          {mac_address: '00:1C:A2:DC:3C:B8', signal_strength: 84, ssid: 'InfostradaWifi'},
          {mac_address: '00:18:F8:7A:CA:C5', signal_strength: 81, ssid: 'prsp'},
          {mac_address: '00:25:4B:0A:63:E5', signal_strength: 80, ssid: 'Network di laura spinella'},
          {mac_address: '00:18:F8:7A:CA:C5', signal_strength: 81, ssid: 'prsp'}
         ]}
       }
  puts 'location.wifi'
  res = http.request_post('/location', loc.to_json, {'Cookie' => cookie})
  puts res.body

  # IP
  loc = {map: {ip_address: {ipv4: '8.8.8.8'}}}
  puts 'location.ip'
  res = http.request_post('/location', loc.to_json, {'Cookie' => cookie})
  puts res.body
end

# fake sync
if false
  puts 'agent.status'
  request = {:ident => 'RCS_0000000001', :instance => '47170c3e047b6a910e7ecc2e987060db2ff06cd9', :subtype => 'WINDOWS'}      
  res = http.request_get('/agent/status/?' + CGI.encode_query(request), {'Cookie' => cookie})
  puts res.body
  
end

# moving target...
if false
  puts 'target.move (to 2)'
  request = {:_id => '4f214b8c2afb65821100006c', :operation => '4f214b8c2afb658211000032'}      
  res = http.request_post('/target/move', request.to_json, {'Cookie' => cookie})
  puts res.body

  puts "target.show"
  res = http.request_get("/target/4f214b8c2afb65821100006c", {'Cookie' => cookie})
  target = JSON.parse(res.body)
  puts target['path'].inspect
  puts

  puts "factory.show"
  res = http.request_get("/factory/4f214b8c2afb6582110000c9", {'Cookie' => cookie})
  factory = JSON.parse(res.body)
  puts factory['path'].inspect
  puts

  puts 'target.move (to 1)'
  request = {:_id => '4f214b8c2afb65821100006c', :operation => '4f214b8c2afb658211000030'}      
  res = http.request_post('/target/move', request.to_json, {'Cookie' => cookie})
  puts res.body

  puts "target.show"
  res = http.request_get("/target/4f214b8c2afb65821100006c", {'Cookie' => cookie})
  target = JSON.parse(res.body)
  puts target['path'].inspect
  puts

  puts "factory.show"
  res = http.request_get("/factory/4f214b8c2afb6582110000c9", {'Cookie' => cookie})
  factory = JSON.parse(res.body)
  puts factory['path'].inspect
  puts
end

# moving agent...
if false
  agent_id = '4f28003c2afb65cf470000cb'

  puts 'agent.move (to 2)'
  request = {:_id => agent_id, :target => '4f28003c2afb65cf4700006e'}      
  res = http.request_post('/agent/move', request.to_json, {'Cookie' => cookie})
  puts res.body

  puts "agent.show"
  res = http.request_get("/agent/#{agent_id}", {'Cookie' => cookie})
  target = JSON.parse(res.body)
  puts target['path'].inspect
  puts
  
  puts 'agent.move (to 1)'
  request = {:_id => agent_id, :target => '4f28003c2afb65cf4700006c'}      
  res = http.request_post('/agent/move', request.to_json, {'Cookie' => cookie})
  puts res.body

  puts "agent.show"
  res = http.request_get("/agent/#{agent_id}", {'Cookie' => cookie})
  target = JSON.parse(res.body)
  puts target['path'].inspect
  puts
end

# forwarder
if false
  # forwarder.index
  puts "forwarder.index" 
  res = http.request_get('/forwarder', {'Cookie' => cookie})
  shards = JSON.parse(res.body)
  puts res.body
  puts
  
  # forwarder.create
  forwarder = {name: 'test', enabled: true, keep: true}
  res = http.request_post('/forwarder/create', forwarder.to_json, {'Cookie' => cookie})
  puts "forwarder.create"
  puts res.body
  puts

  puts "forwarder.index" 
  res = http.request_get('/forwarder', {'Cookie' => cookie})
  shards = JSON.parse(res.body)
  puts res.body
  puts
  
end

# cores
if false
  # core.index
  puts "core.index" 
  res = http.request_get('/core', {'Cookie' => cookie})
  puts res.body
  puts
end

# upload & download
if false
  puts "agent.downloads"
  res = http.request_get("/agent/downloads/4F6059012AFB65C9440000CC", {'Cookie' => cookie})
  puts res.body
  puts
=begin  
  puts "agent.download"
  res = http.request_post("/agent/download", {_id: "4F6059012AFB65C9440000CC", download: {path: "c:\\*.bmp"}}.to_json, {'Cookie' => cookie})
  puts res.body
  puts
  
  puts "agent.downloads"
  res = http.request_get("/agent/downloads/4F6059012AFB65C9440000CC", {'Cookie' => cookie})
  puts res.body
  puts
=end

 puts "agent.uploads"
 res = http.request_get("/agent/uploads/4F6059012AFB65C9440000CC", {'Cookie' => cookie})
 puts res.body
 puts

 puts "agent.upload"
 res = http.request_post("/agent/upload", {_id: "4F6059012AFB65C9440000CC", upload: {filename: "pippo", file: 'test'}}.to_json, {'Cookie' => cookie})
 puts res.body
 puts

 puts "agent.uploads"
 res = http.request_get("/agent/uploads/4F6059012AFB65C9440000CC", {'Cookie' => cookie})
 puts res.body
 puts
end


# logout
res = http.request_post('/auth/logout', nil, {'Cookie' => cookie})
puts
puts "auth.logout"
puts res
puts
