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
      ::PublicDocument.destroy_all({conditions: {name: public[:name]}})

      return ok
    end
  end

end

end #DB::
end #RCS::