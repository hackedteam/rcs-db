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
    return ok(shards)
  end

  def show
    require_auth_level :sys

    stats = Shard.find(@params['_id'])
    return ok(stats)
  end

  def create
    require_auth_level :sys

    # take the peer address as host if requested automatic discovery
    @params['host'] = @request[:peer] if @params['host'] == 'auto'
    
    output = Shard.create "#{@params['host']}:27018"
    return ok(output)
  end

  def destroy
    require_auth_level :sys

    output = Shard.destroy @params['_id']
    return ok(output)
  end

end

end #DB::
end #RCS::