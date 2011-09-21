#
# Controller for the Signature objects
#

module RCS
module DB

class SignatureController < RESTController

  # retrieve the signature for a given entity
  # e.g. 'agent', 'network', ...
  def show
    require_auth_level :server, :admin
    
    begin
      if @params['_id'] == 'cert'
        sig = {}
        sig[:filename] = Config.instance.global['CA_PEM']
        sig[:value] = File.open(Config.instance.file('CA_PEM'), 'rb') {|f| f.read}
        trace :info, "[#{@request[:peer]}] Requested the CA certificate"
      else
        sig = ::Signature.where({scope: @params['_id']}).first
        trace :info, "[#{@request[:peer]}] Requested the '#{@params['_id']}' signature [#{sig[:value]}]"
      end
      return RESTController.reply.ok(sig)
    rescue Exception => e
      trace :warn, "[#{@request[:peer]}] Requested '#{@params['_id']}' NOT FOUND"
      return RESTController.reply.not_found
    end
  end

end

end #DB::
end #RCS::
