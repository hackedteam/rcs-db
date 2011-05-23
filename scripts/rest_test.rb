require 'net/http'
require 'json'
require 'benchmark'

#http = Net::HTTP.new('192.168.1.189', 4444)
http = Net::HTTP.new('localhost', 4444)
http.use_ssl = true
http.verify_mode = OpenSSL::SSL::VERIFY_NONE

# login
account = {
  :user => 'admin', 
  :pass => 'admin'
  }
resp = http.request_post('/auth/login', account.to_json, nil)
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
user = {'name' => 'test', 'pass' => 'test', 'desc' => 'Deus Ex Machina', 'contact' => '', 'privs' => ['ADMIN', 'TECH', 'VIEW'], 'enabled' => true, 'locale' => 'en_US', 'timezone' => 0}
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
group_user = {'group' => test_group['_id'], 'user' => test_user['_id']}
res = http.request_post('/group/add_user', group_user.to_json, {'Cookie' => cookie}) 
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
group_user = {'group' => test_group['_id'], 'user' => test_user['_id']}
res = http.request_post('/group/del_user', group_user.to_json, {'Cookie' => cookie}) 
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
   res = http.request_get('/audit/count', {'Cookie' => cookie})
   puts "audit.count"
   puts res.body.inspect
   puts
   
   res = http.request_get('/audit/count?filter={action: "puddu"}', {'Cookie' => cookie})
   puts "audit.count 'puddu'"
   puts res.body.inspect
   puts
   
   res = http.request_get('/audit/count?filter=%7B%22action%22%3A%22user%2Eupdate%22%7D', {'Cookie' => cookie})
   puts "audit.count 'user.update'"
   puts res.body.inspect
   puts
   
  # audit.index
   res = http.request_get('/audit?filter=%7B%22action%22%3A%22user%2Eupdate%22%7D&startIndex=0&numItems=10', {'Cookie' => cookie})
   puts "audit.index 'user.update'"
   puts res
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
if true
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

# logout
res = http.request_post('/auth/logout', nil, {'Cookie' => cookie})
puts "auth.logout "
puts res
puts
