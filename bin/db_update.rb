require 'mongo'

connection = Mongo::Connection.new
db = connection.db('rcs')

db['items'].find({"_kind" => "target"}).each do |target|
	coll_name = "evidence.#{target['_id']}"
	
	db[coll_name].update({"type" => "message"}, {"$rename" => {"data.body" => "data.content"}}, {:multi => true})
	
	db[coll_name].find({"type" => "message"}).each do |ev|
		db[coll_name].update({"_id" => ev["_id"]}, {"$set" => {"data.type" => ev["data"]["type"].to_s.downcase}}, {:multi => true})
	end
end
