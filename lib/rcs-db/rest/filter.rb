#
# Controller for Evidence Filters
#

module RCS
module DB

class FilterController < RESTController

  def index
    require_auth_level :view

    mongoid_query do
      filters = ::EvidenceFilter.any_of({user: [@session[:user][:_id]]}, {user: []})
      return ok(filters)
    end
  end

  def create
    require_auth_level :view

    mongoid_query do
      f = ::EvidenceFilter.new
      f.user = @params['private'] ? [ @session[:user][:_id] ] : []
      f.name = @params['name']
      f.filter = @params['filter']
      f.save
      
      Audit.log :actor => @session[:user][:name], :action => 'filter.create', :desc => "Created the filter #{@params['name']}"

      return ok(f)
    end    
  end

  def destroy
    require_auth_level :view
    
    mongoid_query do
      filter = ::EvidenceFilter.find(@params['_id'])
      Audit.log :actor => @session[:user][:name], :action => 'filter.destroy', :desc => "Deleted the filter: #{filter[:name]}"
      filter.destroy
      return ok
    end
  end

end

end #DB::
end #RCS::