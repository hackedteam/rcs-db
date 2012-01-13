#
# Controller for License
#

module RCS
module DB

class LicenseController < RESTController

  def limit
    # we use marshalling due to the lack of a deep copy method ...
    limits = Marshal::load(Marshal.dump(LicenseManager.instance.limits)) #LicenseManager.instance.limits.merge({})
    
    # a trick to get the Infinity value
    inf = 1.0/0
    
    # convert the Infinity to null (needed by the JSON deserializer in flex)
    limits[:users] = nil if limits[:users] == inf
    limits[:agents][:total] = nil if limits[:agents][:total] == inf
    limits[:agents][:desktop] = nil if limits[:agents][:desktop] == inf
    limits[:agents][:mobile] = nil if limits[:agents][:mobile] == inf
    limits[:collectors][:collectors] = nil if limits[:collectors][:collectors] == inf
    limits[:collectors][:anonymizers] = nil if limits[:collectors][:anonymizers] == inf
    limits[:nia] = nil if limits[:nia] == inf
    limits[:shards] = nil if limits[:shards] == inf
    
    return ok(limits)
  end
  
  def count
    return ok(LicenseManager.instance.counters)
  end

end

end #DB::
end #RCS::