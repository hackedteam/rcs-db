require_relative '../grid'

module RCS
module DB

class GridController < RESTController
  
  def show
    require_auth_level :tech, :view

    mongoid_query do
      stream_grid(Moped::BSON::ObjectId.from_string(@params['_id']), @params['target_id'])
    end
  end

  def create
    require_auth_level :tech

    mongoid_query do
      grid_id = GridFS.put @request[:content]['content']
      Audit.log :actor => @session[:user][:name], :action => 'grid.upload', :desc => "Uploaded #{@request[:content]['content'].to_s_bytes} bytes into #{grid_id}."

      ok({_grid: grid_id.to_s})
    end
  end

end
  
end # ::DB
end # ::RCS