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

    stats = Shard.find(@params['_id'])

    return RESTController.reply.ok(stats)
  end

  def create
    require_auth_level :sys

    # take the peer address as host if requested automatic discovery
    @params['host'] = @params['peer'] if @params['host'] == 'auto'
    
    output = Shard.create @params['host']
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