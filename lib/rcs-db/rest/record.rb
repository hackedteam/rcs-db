#
# Controller for Target Records
#

module RCS
module DB

class RecordController < RESTController

  def index
    require_auth_level :admin, :view

    mongoid_query do
      records = ::Record.all

      #TODO: filter by accessible

      return ok(records)
    end
  end

  def create
    require_auth_level :admin

    mongoid_query do
      r = ::Record.new
      r.name = @params['name']

      #TODO: other fields

      r.save
      
      Audit.log :actor => @session[:user][:name], :action => 'record.create', :desc => "Created a new record for #{@params['name']}"

      return ok(r)
    end    
  end

  def update
    require_auth_level :admin, :view

    mongoid_query do
      record = ::Record.find(@params['_id'])
      @params.delete('_id')

      @params.each_pair do |key, value|
        if record[key.to_s] != value
          Audit.log :actor => @session[:user][:name], :action => 'record.update', :desc => "Updated record '#{key}' to '#{value}' for #{record[:name]}"
        end
      end

      record.update_attributes(@params)

      return ok(record)
    end
  end

  def destroy
    require_auth_level :admin
    
    mongoid_query do
      record = ::Record.find(@params['_id'])
      Audit.log :actor => @session[:user][:name], :action => 'record.destroy', :desc => "Deleted the record for #{record[:name]}"
      record.destroy
      return ok
    end
  end

end

end #DB::
end #RCS::