require 'net/http'
require 'json'

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

if true 
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
res = http.delete("/user/#{test_user['_id']}", {'Cookie' => cookie}) 
#res = http.delete("/user/12345", {'Cookie' => cookie}) 
puts "user.delete "
puts res
puts

end

if true
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
group = {'name' => 'container'}
res = http.request_put("/group/#{test_group['_id']}", group.to_json, {'Cookie' => cookie}) 
puts "group.update "
puts res
puts

=begin
# group.add_user
group_user = {'group' => test_group['_id'], 'user' => test_user['_id']}
res = http.request_post('/group/add_user', group_user.to_json, {'Cookie' => cookie}) 
puts "group.add_user "
puts res
puts
=end

# group.show
res = http.request_get("/group/#{test_group['_id']}", {'Cookie' => cookie})
puts "group.show"
puts res
puts

# group.destroy
res = http.delete("/group/#{test_group['_id']}", {'Cookie' => cookie}) 
#res = http.delete("/user/12345", {'Cookie' => cookie}) 
puts "group.delete "
puts res
puts
end

# logout
res = http.request_post('/auth/logout', nil, {'Cookie' => cookie})
puts "auth.logout "
puts res
puts
