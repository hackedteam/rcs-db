#
# Controller for License
#

module RCS
module DB

class LicenseController < RESTController

  def limit
    require_auth_level :admin, :tech, :view
    
    return STATUS_OK, *json_reply(LicenseManager.instance.limits)
  end

  def count
    require_auth_level :admin, :tech, :view

    return STATUS_OK, *json_reply(LicenseManager.instance.counters)
  end


end

end #DB::
end #RCS::