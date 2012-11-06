#
# Controller for Config Templates
#

module RCS
module DB

class TemplateController < RESTController

  def index
    require_auth_level :tech
    require_auth_level :tech_config

    mongoid_query do

      templates = ::Template.all

      return ok(templates)
    end
  end

  def create
    require_auth_level :tech
    require_auth_level :tech_config

    mongoid_query do
      t = ::Template.new
      t.desc = @params['desc']
      t.user = @session[:user][:name]
      t.config = @params['config']
      t.save
      
      Audit.log :actor => @session[:user][:name], :action => 'template.create', :desc => "Created a new template: #{@params['desc']}"

      return ok(t)
    end    
  end

  def update
    require_auth_level :tech
    require_auth_level :tech_config

    mongoid_query do
      template = ::Template.find(@params['_id'])
      @params.delete('_id')

      @params.each_pair do |key, value|
        if template[key.to_s] != value
          Audit.log :actor => @session[:user][:name], :action => 'template.update', :desc => "Updated template: #{template[:desc]}"
        end
      end

      template.update_attributes(@params)

      return ok(template)
    end
  end

  def destroy
    require_auth_level :tech
    require_auth_level :tech_config

    mongoid_query do
      template = ::Template.find(@params['_id'])
      Audit.log :actor => @session[:user][:name], :action => 'template.destroy', :desc => "Deleted the template: #{template[:desc]}"
      template.destroy
      return ok
    end
  end

end

end #DB::
end #RCS::