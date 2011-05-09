#
# Controller for the User objects
#

require 'digest/sha1'

module RCS
module DB

class UserController < RESTController

  def index
    users = User.all
    return STATUS_OK, *json_reply(users)
  end

  def show
    begin
      user = User.find(params[:user])
    rescue BSON::InvalidObjectId => e
      trace :error, "Bad request #{e.class} => #{e.message}"
      return STATUS_BAD_REQUEST, *json_reply(e.message)
    rescue Exception => e
      return STATUS_NOT_FOUND, *json_reply(e.message)
    ensure
      return STATUS_NOT_FOUND if user.nil?
    end

    return STATUS_OK, *json_reply(user)
  end
  
  def create
    
    result = User.create(name: @params['name']) do |doc|
      doc[:pass] = Digest::SHA1.hexdigest('.:RCS:.' + @params['pass'])
      doc[:desc] = @params['desc']
      doc[:contact] = @params['contact']
      doc[:privs] = @params['privs']
      doc[:enabled] = @params['enabled']
      doc[:locale] = @params['locale']
      doc[:timezone] = @params['timezone']
    end
    
    return STATUS_CONFLICT, *json_reply(result.errors[:name]) unless result.persisted?
    
    Audit.log :actor => @session[:user], :action => 'user.create', :user => @params['name'], :desc => "Created user '#{@params['name']}'"
    return STATUS_OK, *json_reply(result)
  end
  
  def update
    begin
      user = User.find(params[:user])
    rescue BSON::InvalidObjectId => e
      trace :error, "Bad request #{e.class} => #{e.message}"
      return STATUS_BAD_REQUEST, *json_reply(e.message)
    rescue Exception => e
      return STATUS_NOT_FOUND, *json_reply(e.message)
    ensure
      return STATUS_NOT_FOUND if user.nil?
    end
    
    params.delete(:user)
    result = user.update_attributes(params)
    
    return STATUS_OK, *json_reply(user)
  end
  
  def destroy
    begin
      user = User.find(params[:user])
    rescue BSON::InvalidObjectId => e
      trace :error, "Bad request #{e.class} => #{e.message}"
      return STATUS_BAD_REQUEST, *json_reply(e.message)
    rescue Exception => e
      return STATUS_NOT_FOUND, *json_reply(e.message)
    ensure
      return STATUS_NOT_FOUND if user.nil?
    end
    
    user.destroy
    
    return STATUS_OK
  end

end

end #DB::
end #RCS::