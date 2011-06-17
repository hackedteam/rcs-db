#
# Controller for License
#

module RCS
module DB

class LicenseController < RESTController

  def limit
    require_auth_level :admin, :tech, :view
    
    # we use marshalling due to the lack of a deep copy method ...
    limits = Marshal::load(Marshal.dump(LicenseManager.instance.limits)) #LicenseManager.instance.limits.merge({})
    
    # a trick to get the Infinity value
    inf = 1.0/0
    
    # convert the Infinity to null (needed by the JSON deserializer in flex)
    limits[:users] = nil if limits[:users] == inf
    limits[:backdoors][:total] = nil if limits[:backdoors][:total] == inf
    limits[:backdoors][:desktop] = nil if limits[:backdoors][:desktop] == inf
    limits[:backdoors][:mobile] = nil if limits[:backdoors][:mobile] == inf
    limits[:collectors][:collectors] = nil if limits[:collectors][:collectors] == inf
    limits[:collectors][:anonymizers] = nil if limits[:collectors][:anonymizers] == inf
    limits[:ipa] = nil if limits[:ipa] == inf
    
    return RESTController.ok(limits)
  end
  
  def count
    require_auth_level :admin, :tech, :view

    return RESTController.ok(LicenseManager.instance.counters)
  end

end

end #DB::
end #RCS::