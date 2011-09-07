#
# Controller for the Shards (distributed servers)
#
require 'cgi'

module RCS
module DB

class ShardController < RESTController

  def index
    require_auth_level :sys

    shards = Shard.all
    return RESTController.reply.ok(shards)
  end

  def show
    require_auth_level :sys

    # it could contain special chars such as colon (:)
    shard = CGI.unescape(@params['_id'])

    stats = Shard.find(shard)

    return RESTController.reply.ok(stats)
  end

  def create
    require_auth_level :sys

    output = Shard.create @params['_id']
    return RESTController.reply.ok(output)
  end

  def destroy
    require_auth_level :sys

    output = Shard.destroy @params['_id']
    return RESTController.reply.ok(output)
  end

end

end #DB::
end #RCS::